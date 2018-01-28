﻿Shader "VolumeRendering/VolumeRendering4"
{

Properties
{
    [Header(Rendering)]
    _Volume("Volume", 3D) = "" {}
    _Transfer("Transfer", 2D) = "" {}
    _Iteration("Iteration", Int) = 10
    _Intensity("Intensity", Range(0.0, 1.0)) = 0.1
    _Ambient("Ambient", Range(0.0, 1.0)) = 0.1
    _Shadow("Shadow", Range(0.0, 5.0)) = 2.0
    [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 5
    [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10

    [Header(Ranges)]
    _MinX("MinX", Range(0, 1)) = 0.0
    _MaxX("MaxX", Range(0, 1)) = 1.0
    _MinY("MinY", Range(0, 1)) = 0.0
    _MaxY("MaxY", Range(0, 1)) = 1.0
    _MinZ("MinZ", Range(0, 1)) = 0.0
    _MaxZ("MaxZ", Range(0, 1)) = 1.0

    [Header(Variable)]
    [KeywordEnum(VARIABLE_LENGTH, FIXED_LENGTH)] 
    _RAY("Ray Method", Float) = 0
}

CGINCLUDE

#include "UnityCG.cginc"

struct appdata
{
    float4 vertex : POSITION;
};

struct v2f
{
    float4 vertex   : SV_POSITION;
    float4 localPos : TEXCOORD0;
    float4 worldPos : TEXCOORD1;
};

sampler3D _Volume;
sampler2D _Transfer;
int _Iteration;
float _Intensity;
fixed _MinX, _MaxX, _MinY, _MaxY, _MinZ, _MaxZ;
float _Ambient;
float _Shadow;

struct Ray
{
    float3 from;
    float3 dir;
    float tmax;
};

void intersection(inout Ray ray)
{
    float3 invDir = 1.0 / ray.dir;
    float3 t1 = (-0.5 - ray.from) * invDir;
    float3 t2 = (+0.5 - ray.from) * invDir;

    float3 tmax3 = max(t1, t2);
    float2 tmax2 = min(tmax3.xx, tmax3.yz);
    ray.tmax = min(tmax2.x, tmax2.y);
}

inline fixed4 sampleVolume(float3 pos)
{
    fixed x = step(pos.x, _MaxX) * step(_MinX, pos.x);
    fixed y = step(pos.y, _MaxY) * step(_MinY, pos.y);
    fixed z = step(pos.z, _MaxZ) * step(_MinZ, pos.z);
    return tex3D(_Volume, pos) * (x * y * z);
}

inline fixed4 transferFunction(float t)
{
    return tex2D(_Transfer, float2(t, 0));
}

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.localPos = v.vertex;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    return o;
}

fixed4 frag(v2f i) : SV_Target
{
    float3 worldDir = i.worldPos - _WorldSpaceCameraPos;
    float3 localDir = normalize(mul(unity_WorldToObject, worldDir));

    Ray ray;
    ray.from = i.localPos;
    ray.dir = localDir;
    intersection(ray);

#ifdef _RAY_FIXED_LENGTH
    float dt = 1.0 / _Iteration;
    float time = 0.0;
    float3 localStep = localDir * dt;
#else
    float3 localStep = localDir * ray.tmax / _Iteration;
#endif
    float3 localPos = i.localPos;
    float4 output = 0;
    float3 lightDir = normalize(mul(unity_WorldToObject, _WorldSpaceLightPos0));

    [loop]
    for (int i = 0; i < _Iteration; ++i)
    {
        fixed4 volume = sampleVolume(localPos + 0.5);
        fixed a = volume.a;
        fixed3 normal = 2.0 * volume.rgb - 1.0;
        fixed shadow = dot(lightDir, -normal);
        fixed4 color = transferFunction(a) * a * _Intensity;
        color.rgb *= _Ambient + (1.0 - shadow * _Shadow);
        output += (1.0 - output.a) * color;
        localPos += localStep;
#ifdef _RAY_FIXED_LENGTH
        time += dt;
        if (time > ray.tmax || output.a > 0.95) break;
#endif
    }

    return output;
}

ENDCG

SubShader
{

Tags 
{ 
    "Queue" = "Transparent"
    "RenderType" = "Transparent" 
}

Pass
{
    Tags { "LightMode" = "ForwardBase" }

    Cull Back
    ZWrite Off
    Blend [_BlendSrc] [_BlendDst]

    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile _RAY_VARIABLE_LENGTH _RAY_FIXED_LENGTH
    ENDCG
}

}

}