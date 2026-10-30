vec4 mixColors(vec4 color1, vec4 color2, float factor){
	return mix(color1, color2, factor);
}

vec4 tint(vec4 color, vec4 tintColor){
	return tintColor * color;
}