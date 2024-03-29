#version 330 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 binormal;
layout(location = 3) in vec2 texcoord;
layout(location = 4) in vec4 bone_indices;
layout(location = 5) in vec4 bone_weights;

#define maxLight 8
#define maxBones 64

uniform int skinning_transformsNum;
uniform mat4 skinning_transforms[maxBones];

uniform struct Transform
{
	mat4 model;
	mat4 viewProjection;
	mat3 normal;
	vec3 viewPosition;
        mat4 modelViewProjection;
} transform;

out Vertex {
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

void main(void)
{
	vec4 skinnedVertex = vec4(0, 0, 0, 0);
	vec4 vert = vec4(position, 1.0);
	
	mat4 MVI = bone_weights[0]*skinning_transforms[int(bone_indices[0])];
	MVI += bone_weights[1]*skinning_transforms[int(bone_indices[1])];
	MVI += bone_weights[2]*skinning_transforms[int(bone_indices[2])];
	MVI += bone_weights[3]*skinning_transforms[int(bone_indices[3])];
	skinnedVertex = MVI * vert;	
	mat3 MVIN = mat3(transpose(inverse(MVI)));

	vec4 vertex   =  transform.model * skinnedVertex;
	Vert.normal   = normalize(transform.normal * MVIN * normal);

	Vert.texcoord = texcoord;
	Vert.position = vec4(position, 1);
	gl_Position = transform.viewProjection * vertex;
}
