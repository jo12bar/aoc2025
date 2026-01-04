shader_type canvas_item;
render_mode blend_mix;
// gbc-screen-shader.gdshader
// 
// This shader emulates the Game Boy Color screen, with a configurable 4-color
// output palette, glare amount, screen brightness, dot-matrix effect, and
// colour correciton adapted from Gambatte.
// 
// This shader is an amalgamation of the following:
// 
// - The "Ultimate Gameboy (Color) Shader" by Goofy Gourd Studios found here:
//   https://godotshaders.com/shader/ultimate-gameboy-color-shader/
// - tpnk-dev's gameboy-dot-matrix-filter-godot, found here:
//   https://github.com/tpnk-dev/gameboy-dot-matrix-filter-godot
// - LiterallyAnyone's "Extensible Color Palette (Uniform Colors)" shader
//   found here: https://godotshaders.com/shader/extensible-color-palette/
// - The GLSL port of the Gambatte emulator's colour-correcrtion shader that
//   libretro uses, found here:
//   https://github.com/libretro/glsl-shaders/blob/master/handheld/shaders/color/gbc-gambatte-color.glsl
// 
// I ported everything to Godot 4, fixed some dot matrix scaling bugs, made it
// work more as a "screen-wide" shader than a sprite texture shader, and made
// some other tweaks to my liking.
// 
// For proper colour conversions, it's best if all sprites use one of the following
// four greyscale values as their original colours:
// 
// - Black:      #000000
// - Dark grey:  #606060
// - Light grey: #a8a8a8
// - White:      #f8f8f8

/**
 * Size of dots on the LCD's dot-matrix grid, in screen-space pixels. Set this
 * to whatever scale the Game Boy sprites are being rendered at compared to the
 * Game Boy's actual resolution (i.e. 4.0 if you're upscaling to 4x resolution).
 */
uniform float dot_size = 4.0;
/** Default size of the viewport in pixels (used for scaling the dot-matrix effect). */
uniform vec2 viewport_base_size = vec2(720.0, 656.0);

/**
 * First output color palette colour. This is normally the brightest foreground
 * colour, and correponds to a white greyscale source colour.
 */
uniform vec4 palette_color_0: source_color;
/**
 * Second output color palette colour. Corresponds to a dark-grey greyscale
 * source colour.
 */
uniform vec4 palette_color_1: source_color;
/**
 * Third output color palette colour. Corresponds to a light-grey greyscale
 * source colour.
 */
uniform vec4 palette_color_2: source_color;
/**
 * Fourth output color palette colour. Will be used as the background colour,
 * and normally corresponds to a black greyscale source colour.
 */
uniform vec4 palette_color_3: source_color;

/** If true, will superimpose some LCD textures and scratches onto the background. */
uniform bool use_image_for_lcd_back = true;
/** Source image to use for LCD textures and scratches. */
uniform sampler2D lcd_back_image: source_color;

/** Size of the border around the dot-matrix, in screen-space pixels. */
uniform float border_size = 40.0;
/** Set to true to enable the dot-matrix effect. */
uniform bool enable_dot_matrix_effect = true;

/** How much light glare should be shown on the screen. Set to 0 to disable the glare effect. */
uniform float glare_amount = 0.15;
/** Brightness of the screen (as in, how much light is hitting the back of the LCD and reflecting off. */
uniform float brightness : hint_range(0, 1) = 0.4;
/** How much shadow the dot-matrix's pixels cast on the back of the LCD. */
uniform float pixel_shadow_amount : hint_range(0, 1) = 0.3;

/** How opaque the LCD pixels are to light. Higher values result in darker pixels. */
uniform float lcd_dark_square_opacity : hint_range(0.0, 1.0) = 0.03;

/**
 * Set to true to enable colour correction inspired by the Gambatte emulator,
 * which is intended to better replicate the look of a Game Boy LCD in real life.
 * Essentially, this de-saturates, softens, and slightly darkens the R, G, and B
 * channels of the output palette colours by various amounts.
 */
uniform bool enable_color_correction = true;

/** Converts an RGB colour to a greyscale value. */
float color_to_grey_value(vec3 color_input) {
	return max(max(color_input.r, color_input.g), color_input.b);
}

void fragment() {
	vec4 previous_pass = texture(TEXTURE, UV);
	vec2 screen_resolution = vec2(1.0 / SCREEN_PIXEL_SIZE.x, 1.0 / SCREEN_PIXEL_SIZE.y);
	
	// Define color list for the color palette
	vec4 colors[] = {palette_color_0, palette_color_1, palette_color_2, palette_color_3};
	vec4 background_color = colors[3];
	
	// Setup LCD back by mixing its pixels into the color palette
	if (use_image_for_lcd_back) {
		vec4 lcd_back_tex = texture(lcd_back_image, UV);
		colors[0] *= lcd_back_tex;
		colors[1] *= lcd_back_tex;
		colors[2] *= lcd_back_tex;
		colors[3] *= lcd_back_tex;
		// Remember to update the background color so it still shows the LCD texture
		background_color = colors[3];
	}
	
	// Get raw existing texture data from the screen
	vec3 color_input = previous_pass.rgb;
	float alpha_input = previous_pass.a;
	
	// Force everything to be greyscale
	float grey_value = color_to_grey_value(color_input);
	
	// Round greyscale values into however many grey gradient steps as there
	// are colours in the `colors` array, and then use that to index into the
	// color palette.
	int grey_index = int(round(grey_value * float(colors.length() - 1)));
	vec4 selected_palette_color = colors[grey_index];
	
	COLOR = selected_palette_color;
	COLOR.a = alpha_input;
	
	// Figure out how big the dot-matrix dots should _actually_ be based on the current screen size. This basically scales the dot-matrix effect to match the
	// actual rendered resolution.
	vec2 actual_dot_size = vec2(
		dot_size / (viewport_base_size.x * SCREEN_PIXEL_SIZE.x),
		dot_size / (viewport_base_size.y * SCREEN_PIXEL_SIZE.y)
	);
	
	// Snap current pixel to whatever the dot_size uniform says it should be
	int modulus_x = int(mod(FRAGCOORD.x, actual_dot_size.x));
	int modulus_y = int(mod(FRAGCOORD.y, actual_dot_size.y));
	
	// Setup LCD squares
	if (enable_dot_matrix_effect) {
		if (
			FRAGCOORD.x < screen_resolution.x - border_size
			&& FRAGCOORD.x > border_size
			&& FRAGCOORD.y > border_size
			&& FRAGCOORD.y < screen_resolution.y - border_size
		) {
			// We're within `border_size` pixels on all sides of the screen, so we can apply
			// the dot matrix effect. Check if we're on a dot-matrix line or not:
			if (modulus_x != 0 && modulus_y != 0) {
				// We're between dot-matrix lines, so show the current texture, but darken it
				// by lcd_dark_square_opacity
				COLOR.rgb = mix(COLOR.rgb, vec3(0.0, 0.0, 0.0), lcd_dark_square_opacity);
			}
		}
	}
	
	// Setup colored pixels
	// We measure "whiteness" by just checking the r component of the previous
	// texture pass, and then render the foreground palette color (darkened a bit),
	// and set alpha to whatever the configured brightness is multiplied by the
	// inverse of pixel_whiteness.
	float pixel_whiteness = previous_pass.r;
	vec4 colored_frame = vec4(
		COLOR.r - 0.3,
		COLOR.g - 0.3,
		COLOR.b - 0.3,
		brightness * (1.0 - pixel_whiteness)
	);
	
	if (abs(pixel_whiteness - 248.0 / 255.0) < 0.01 || COLOR.a < 0.0001) {
		// pixel whiteness is above threshold, pr the texture is transparent here, so just don't
		// render the pixel
	} else {
		if (enable_dot_matrix_effect) {
			if (modulus_x != 0 && modulus_y != 0) {
				// We're between dot-matrix lines, so show the previously-darked frame,
				// remembering to flip alpha again (since we previously flipped it above when
				// calculating colored_frame)
				COLOR = mix(colored_frame, COLOR, 1.0 - colored_frame.a);
			} else {
				// We're on a dot-matrix line! So render a primitive shadow.
				if (colored_frame.a > 0.0) {
					// Though of course, we only render the shadow wherever the colored_frame
					// has a non-zero alpha so that transparent sprites don't get messed up.
					COLOR = mix(
						COLOR,
						vec4(0.0, 0.0, 0.0, 1.0),
						pixel_shadow_amount * brightness * (1.0 - pixel_whiteness * 0.4)
					);
				}
			}
		} else {
			// Dot-matrix effect is turned off, so just render the current frame,
			// and remember to flip the alpha again (since we flipped it above when
			// calculating colored_frame).
			COLOR = mix(colored_frame, COLOR, 1.0 - colored_frame.a);
		}
	}
	
	// Apply colour correction to make colour output closer to the GBC, generally
	// with softer, less-saturated colours.
	if (enable_color_correction) {
		// Adapted from the GLSL port of the Gambatte emulator's color correction shader found in
		// libretro's source code.
		// We use a colour correction matrix, and then "scale" it to affect how
		// much it affects each colour channel. Note that we could've used the
		// integer-math method found in libretro's source instead, but it performs
		// worse, even if it's a little bit more accurate.
		mat3 color_correction = mat3(
			vec3(13.0, 2.0, 1.0),
			vec3(0.0, 3.0, 1.0),
			vec3(3.0, 2.0, 11.0)
		);
		mat3 scale = mat3(
			vec3(1.0/16.0, 0.0, 0.0),
			vec3(0.0, 1.0/4.0, 0.0),
			vec3(0.0, 0.0, 1.0/16.0)
		);
		color_correction *= scale;
		COLOR.rgb *= color_correction;
	}
	
		
	// Apply glare
	vec3 glare = vec3(
		(FRAGCOORD.x / screen_resolution.x) / 2.0
		+ (FRAGCOORD.y / screen_resolution.y) / 2.0
	);
	COLOR.rgb += glare * glare_amount;
}
