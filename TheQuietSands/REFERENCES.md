# References and attribution

All scene geometry, texture data, sound data, and Godot implementation files in this project were created for The Quiet Sands. No Journey assets, Unity project assets, photo textures, or assets from the previous local project are included.

- John Edwards, thatgamecompany: [Sand Rendering in Journey, GDC 2013](https://www.gdcvault.com/play/1018864/Sand-Rendering-in). Also studied the author's [SIGGRAPH 2012 slides and speaker notes](https://advances.realtimerendering.com/s2012/thatgamecompany/SandRenderingInJourney_thatgamecompany.pptx). The material draws on contrast-shaped diffuse lighting, an ocean-like specular component, Gaussian surface normals, view-dependent glitter, directional detail blending, and filtering at grazing angles. The source presentation describes an artistic approximation rather than a physically exact sand model.
- Alan Zucconi: [A Journey Into Journey's Sand Shader](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-1/), including [diffuse](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-2/), [normals](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-3/), [specular](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-4/), [glitter](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-5/), and [ripples](https://www.alanzucconi.com/2019/10/08/journey-sand-shader-6/). Credit is given as requested by the tutorial author. The Godot shader is an original implementation informed by this series, not a copied Unity shader.
- Jiadi Deng / AtwoodDeng: [JourneySand](https://github.com/AtwoodDeng/JourneySand), licensed CC BY-SA 4.0. The documented Oren–Nayar, directional normal, Blinn–Phong, and post-processing breakdown was consulted. No code, textures, meshes, or other files were copied from this repository. The Quiet Sands uses a smoother contrast-diffuse response instead of adopting that implementation.
- hungryproton: [Seamless texture sampler without repeating patterns / tiling](https://godotshaders.com/shader/seamless-texture-sampler-without-repeating-patterns-tiling/), 2025, based on Iñigo Quílez's texture-repetition techniques. The sand's two decorrelated, gradient-preserving samples use the same general approach with a procedural mixing field. The original snippet is MIT licensed; its notice is retained below for attribution.
- Godot Engine: the installed 4.7.2 API documentation and [official class reference](https://docs.godotengine.org/en/stable/classes/index.html).

## MIT notice for the non-repeating sampling reference

Copyright (c) 2025 hungryproton

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
