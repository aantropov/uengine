#extension GL_NV_shadow_samplers_cube : enable
#define maxLight 8

#if defined(VERTEX)
	#define inout out
#elif defined(FRAGMENT)
	#define inout in
#endif

uniform struct Transform
{
	mat4 model;
	mat4 viewProjection;	
	mat3 normal;
	vec3 viewPosition;
    mat4 modelViewProjection;
} transform;

uniform struct Material
{
	sampler2D texture;
	sampler2D specular_tex;
	
#if defined(NORMAL)
	sampler2D normal;
#endif

	vec4  ambient;
	vec4  diffuse;
	vec4  specular;
	vec4  emission;
	float shininess;
	
#if defined(REFLECTION_CUBEMAP)
	samplerCube cubemap;
#endif

} material;

inout Vertex 
{
	vec4  position;
	vec2  texcoord;
	vec3  normal;
	vec3  lightDir[maxLight];
	vec3  lightDirTBN[maxLight];
	vec3  viewDirTBN;
	vec3  viewDir;
	vec4 smcoord[maxLight];	
	vec3 t;
	vec3 b;
	mat3 transformNormal;
} Vert;

#if defined(SKINNING)
uniform int skinning_transformsNum;
uniform mat4 skinning_transforms[maxBones];
#endif 

uniform int lightsNum;
uniform vec4 light_position[maxLight];
uniform vec4 light_ambient[maxLight];
uniform vec4 light_diffuse[maxLight];
uniform vec4 light_specular[maxLight];
uniform vec3 light_attenuation[maxLight];
uniform vec3 light_spotDirection[maxLight];
uniform float light_spotExponent[maxLight];
uniform float light_spotCosCutoff[maxLight];
uniform mat4 light_transform[maxLight];
uniform sampler2DShadow light_depthTexture[maxLight];

#if defined(VERTEX)

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 binormal;
layout(location = 3) in vec2 texcoord;

void ProcessLight(int i, vec4 vertex, vec3 t, vec3 b, vec3 n)
{
	Vert.smcoord[i]  = light_transform[i] * vertex;
	vec3 lightDir = vec3(light_position[i] - vertex);
	
	Vert.lightDir[i] = lightDir;

	Vert.lightDirTBN[i].x = dot(lightDir, t);
	Vert.lightDirTBN[i].y = dot(lightDir, b);
	Vert.lightDirTBN[i].z = dot(lightDir, n);
}

void main(void)
{
#if defined(SKINNING)
	vec4 skinnedVertex = vec4(0, 0, 0, 0);
	vec4 vertex = vec4(position, 1.0);
	
	mat4 MVI = bone_weights[0]*skinning_transforms[int(bone_indices[0])];
	MVI += bone_weights[1]*skinning_transforms[int(bone_indices[1])];
	MVI += bone_weights[2]*skinning_transforms[int(bone_indices[2])];
	MVI += bone_weights[3]*skinning_transforms[int(bone_indices[3])];
	skinnedVertex = MVI * vertex;	
	mat3 MVIN = mat3(transpose(inverse(MVI)));

	vertex = transform.model * skinnedVertex;	
#else
	vec4 vertex = transform.model * vec4(position, 1.0);
#endif	
		
	Vert.texcoord = texcoord;
	Vert.position = vertex;		
	
	Vert.transformNormal = transform.normal;

	vec3 n = Vert.transformNormal * normal;
	Vert.b = Vert.transformNormal * binormal;
	Vert.t = (cross(n, Vert.b));

#if defined(SKINNING)
	Vert.normal = normalize(transform.normal * MVIN * normal);
#else
	Vert.normal = normalize(normal);
#endif

	Vert.viewDir = normalize(vec3(transform.viewPosition - vec3(vertex)));
	
	Vert.viewDirTBN.x = dot(Vert.viewDir, Vert.t);
	Vert.viewDirTBN.y = dot(Vert.viewDir, Vert.b);
	Vert.viewDirTBN.z = dot(Vert.viewDir, n);
	
	for(int i = 0; i < min(maxLight, lightsNum); i++)
		ProcessLight(i, vertex, Vert.t, Vert.b, n);
	
	gl_Position = transform.viewProjection * (vertex);	
}

#elif defined(FRAGMENT)

out vec4 color[6];

float SampleShadow(in vec4 smcoord, sampler2DShadow depthTexture)
{
#if defined(SHADOWS_PCF)
	float res = 0.0;

	res += textureProjOffset(depthTexture, smcoord, ivec2(-1,-1));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 0,-1));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 1,-1));
	res += textureProjOffset(depthTexture, smcoord, ivec2(-1, 0));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 0, 0));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 1, 0));
	res += textureProjOffset(depthTexture, smcoord, ivec2(-1, 1));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 0, 1));
	res += textureProjOffset(depthTexture, smcoord, ivec2( 1, 1));

	return (res / 9.0);
#else
	return textureProjOffset(depthTexture, smcoord, ivec2( 0, 0));
#endif
}

float ProccessLight(int i)
{	
	float shadow = clamp(SampleShadow(Vert.smcoord[i], light_depthTexture[i]), 0.0, 1.0);
	vec3 lightDirLight = normalize(Vert.lightDir[i]);
	float spotEffect = dot(normalize(light_spotDirection[i]), -lightDirLight);
	float spot       = float(spotEffect > light_spotCosCutoff[i]);
	spotEffect = max(pow(spotEffect, light_spotExponent[i]), 0.0);

	return shadow * spot * spotEffect;
}

void main(void)
{
	vec3 normal = Vert.normal;
#ifdef NORMAL
	normal = texture(material.normal, Vert.texcoord).xyz * 2.0 - 1.0;
    mat3 m = mat3((Vert.t), (Vert.b), (Vert.normal));
	normal *= transpose(m);
#endif

	vec4 specular = texture(material.specular_tex, Vert.texcoord);
	
	float res = 0.0;
	for(int i = 0; i < min(maxLight,lightsNum); i++)
	 res += ProccessLight(i);    
    
    color[0] =  material.emission;
    
#if defined(REFLECTION_CUBEMAP)
    vec3 viewDir = normalize(Vert.viewDir);
    vec3 reflectDir = normalize(reflect(viewDir, normal));
    vec4 reflectColor = vec4(textureCube(material.cubemap, reflectDir)) * pow(1 - dot(Vert.normal, viewDir), 3);
    color[0] += reflectColor;
#endif
	
	color[1] = vec4(normal * 0.5 + vec3(0.5), 1.0);
	color[2] = material.diffuse * clamp(res, 0, 1.0) * texture(material.texture, Vert.texcoord);
	color[3] = material.ambient * clamp(res, 0, 1.0);
	color[4] = vec4(material.specular.xyz * specular.xyz * clamp(res, 0, 1.0), material.shininess);// * material.specular.w * specular.w;
	color[5] = Vert.position;
	//color[6] = vec4(0.0f);
}
#endif
