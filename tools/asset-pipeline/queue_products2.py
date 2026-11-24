import json, urllib.request
items = {
    "barsoap": "a single plain rectangular pink bar soap with rounded edges",
    "serum2": "a single plain frosted glass serum dropper bottle with peach tinted liquid and rose gold dropper",
    "sunscreen_tube": "a single plain soft pink sunscreen squeeze tube lying diagonally",
    "sunscreen_bottle": "a single plain slim pink serum bottle with white pump cap",
    "sunscreen_gel": "a single plain translucent light pink gel tube with clear cap",
    "sunscreen_tube2": "a single plain coral pink flat sunscreen tube standing upright with round cap",
    "eyeshadow": "a single open pastel eyeshadow palette with nine pink and peach shimmer pans",
    "lipglaze": "a single clear glass lip glaze tube with rosy liquid and a pink cap",
    "bodyserum2": "a single plain tall frosted pink body serum bottle with silver pump",
}
neg = "text, letters, words, typography, label, sticker, print, logo, brand name, watermark, numbers, people, hands, multiple products, clutter, dark"
ids = {}
for i, (name, desc) in enumerate(items.items()):
    wf = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "realvisxlV50_v50LightningBakedvae.safetensors"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": f"professional cosmetic product photography, {desc}, completely blank surface with no label and no print, on a glossy round pink podium, pastel blush pink background, soft studio lighting, clean minimal, centered"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": neg}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 768, "height": 768, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {"seed": 13000 + i, "steps": 6, "cfg": 1.8, "sampler_name": "dpmpp_sde", "scheduler": "karras", "denoise": 1, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"filename_prefix": f"bpedia_prod3_{name}", "images": ["6", 0]}},
    }
    req = urllib.request.Request("http://127.0.0.1:8188/prompt", data=json.dumps({"prompt": wf}).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        ids[name] = json.loads(r.read())["prompt_id"]
print(json.dumps(ids, indent=1))
