﻿// Upgrade NOTE: upgraded instancing buffer 'Props' to new syntax.

Shader "sidefx/vertex_rigid_body_shader" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_boundingMax("Bounding Max", Float) = 1.0
		_boundingMin("Bounding Min", Float) = 1.0
		_boundingMax1("Bounding Max1", Float) = 1.0
		_boundingMin1("Bounding Min1", Float) = 1.0
		_numOfFrames("Number Of Frames", int) = 240
		_speed("Speed", Float) = 0.33
		[MaterialToggle] _Lerp("Lerp", Float) = 0
		_timeoffset("Time Offset", Range(0,1)) = 0.0
		_posTex ("Position Map (RGB)", 2D) = "white" {}
		_rotTex ("Rotation Map (RGB)", 2D) = "grey" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard addshadow vertex:vert

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
		#pragma fragmentoption ARB_precision_hint_nicest

		sampler2D _MainTex;
		sampler2D _posTex;
		sampler2D _rotTex;
		uniform float _boundingMax;
		uniform float _boundingMin;
		uniform float _boundingMax1;
		uniform float _boundingMin1;
		uniform int _numOfFrames;
		uniform float _speed;
		uniform float _timeoffset;
		uniform int _Lerp;

		struct Input {
			float2 uv_MainTex;
			float4 color: COLOR;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		UNITY_INSTANCING_BUFFER_END(Props)

		float4 Slerp(float4 p0, float4 p1, float t)
		{
			float dotp = dot(normalize(p0), normalize(p1));
			if ((dotp > 0.9999) || (dotp < -0.9999))
			{
				if (t <= 0.5)
					return p0;
				return p1;
			}
			float theta = acos(dotp * 3.14159 / 180.0);
			float4 P = ((p0*sin((1 - t)*theta) + p1 * sin(t*theta)) / sin(theta));
			P.w = 1;
			return P;
		}


		//vertex function
		void vert(inout appdata_full v){
			//calculate uv coordinates
			float timeInFrames = ((ceil(frac(_Time.y * _speed + _timeoffset) * _numOfFrames))/_numOfFrames) + (1.0/_numOfFrames);

			//get position and rotation(quaternion) from textures
			float3 texturePos = tex2Dlod(_posTex,float4(v.texcoord1.x, (1 - timeInFrames) + v.texcoord1.y, 0, 0));
			float4 textureRot = tex2Dlod(_rotTex,float4(v.texcoord1.x, (1 - timeInFrames) + v.texcoord1.y, 0, 0));
			float3 texturePos2 = tex2Dlod(_posTex, float4(v.texcoord1.x, (1 - timeInFrames) -(1.0 / _numOfFrames) + v.texcoord1.y, 0, 0));
			float4 textureRot2 = tex2Dlod(_rotTex, float4(v.texcoord1.x, (1 - timeInFrames) -(1.0 / _numOfFrames) + v.texcoord1.y, 0, 0));
			texturePos = lerp(texturePos, texturePos2, _Lerp * frac(frac(_Time.y* _speed + _timeoffset) * _numOfFrames));
			//comment out the 2 lines below if your colour space is set to linear
			//texturePos.xyz = pow(texturePos.xyz, 2.2);
			//textureRot.xyz = pow(textureRot.xyz, 2.2);

			//expand normalised position texture values to world space
			float expand1 = _boundingMax1 - _boundingMin1;
			texturePos.xyz *= expand1;
			texturePos.xyz += _boundingMin1;
			//texturePos.x *= -1;  //flipped to account for right-handedness of unity
			//texturePos = texturePos.xzy;  //swizzle y and z because textures are exported with z-up

			//expand normalised pivot vertex colour values to world space
			float3 pivot = v.color.rgb;
			float expand = _boundingMax - _boundingMin;
			pivot.xyz *= expand;
			pivot.xyz += _boundingMin;
			//pivot.x *= -1;
			//pivot = pivot.xzy;

			float3 atOrigin = v.vertex.xyz - pivot;

			//calculate rotation
			textureRot *= 2.0;
			textureRot -= 1.0;
			textureRot2 *= 2.0;
			textureRot2 -= 1.0;
			//textureRot.xyz *= -1;
			//textureRot = textureRot.rbga;

			float3 rotated = atOrigin + 2.0 * cross(textureRot.xyz, cross(textureRot.xyz, atOrigin) + textureRot.w * atOrigin);
			float3 rotated2 = atOrigin + 2.0 * cross(textureRot2.xyz, cross(textureRot2.xyz, atOrigin) + textureRot2.w * atOrigin);
			rotated = lerp(rotated, rotated2, _Lerp * frac(frac(_Time.y * _speed + _timeoffset) * _numOfFrames));

			v.vertex.xyz = rotated;
			v.vertex.xyz += texturePos.xyz;

			//calculate normal
			float3 rotatedNormal = v.normal + 2.0 * cross(textureRot.xyz, cross(textureRot.xyz, v.normal) + textureRot.w * v.normal);
			float3 rotatedNormal2 = v.normal + 2.0 * cross(textureRot2.xyz, cross(textureRot2.xyz, v.normal) + textureRot2.w * v.normal);
			rotatedNormal = lerp(rotatedNormal, rotatedNormal2, _Lerp * frac(frac(_Time.y * _speed + _timeoffset) * _numOfFrames));
			v.normal = rotatedNormal;
			v.color.rgb = texturePos;
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
