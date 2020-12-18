// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/CelShadingV2"
{
	Properties
	{
		_MainTex("BaseTexture", 2D) = "white"{}
		_OutlineColor("Outline Color",Color) = (0.1,0.1,0.1,1)
		_OutlineWidth("Outline Width",Range(0.001,1)) = 0.01
		_SpecularColor("SpecularColor", Color) = (1,1,1,1) // 控制材质反光
		_SpecularTex("SpecularTexture", 2D) = "white"{} // 控制材质反光
		_SpecularRange("SpecularRange", Range(0,2)) = 0
		_SpecularBrightness("SpecularBrightness", Range(0,1)) = 1 // 控制材质反光
		_MiddleBrightness("MiddleBrightness",Range(0,1)) = 1
		_ShadowRange("ShadowRange", Range(-1,1)) = 1
		_ShadowColor("ShadowColor", Color) = (1,1,1,1)
		_ShadowTex("Shadow Texture", 2D) = "white"{} // 边缘光
		_ShadowBrightness("ShadowBrightness",Range(0,1)) = 1
		_RimColor("Rim Color", Color) = (1,1,1,0) // 边缘光
		_RimTex("Rim Texture", 2D) = "white"{} // 边缘光
		_RimPower("Rim Power",Range(0,10)) = 1
		_RimIntensity("【边缘发光强度系数】Rim Power Intensity",Range(0,30)) = 1

	}
		SubShader
		{
			Pass{

				Tags{ 
				"RenderType" = "Transparent" 
				"Queue" = "Transparent" 
				"LightMode" = "LightweightForward"
				}

				Blend SrcAlpha OneMinusSrcAlpha
				Name "CELSHADINGPASS"

				HLSLPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "UnityCG.cginc"
				#include "Lighting.cginc"

				struct v2f {
					float4 pos :  SV_POSITION;
					float3 worldNormal : TEXCOORD0;
					float2 uv : TEXCOORD1;
					float3 worldPos : TEXCOORD2;
				};

				sampler2D _MainTex;
				sampler2D _SpecularTex;
				sampler2D _ShadowTex;
				sampler2D _RimTex;

				fixed4 _SpecularColor;
				fixed4 _ShadowColor;
				fixed4 _RimColor;
				float4 _MainTex_ST;
				float _SpecularRange;
				float _ShadowRange;

				float _ShadowBrightness;
				float _SpecularBrightness;
				float _MiddleBrightness;
				float _RimPower;
				float _RimIntensity;
				v2f vert(appdata_base v) {
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.worldNormal = UnityObjectToWorldNormal(v.normal);// mul(v.normal, (float3x3)unity_WorldToObject);
					o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					return o;
				}

				fixed4 frag(v2f i) : SV_Target{
					half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
					half3 worldNormal = normalize(i.worldNormal);
					half3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
					half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);

					fixed4 mainTex = tex2D(_MainTex, i.uv);
					fixed4 specularTex = tex2D(_SpecularTex, i.uv);
					fixed4 rimTex = tex2D(_RimTex, i.uv);
					fixed4 shadowTex = tex2D(_ShadowTex, i.uv);
					// compute shadow term
					float shadowRange = 1 - step(_ShadowRange * 2, dot(worldNormal, worldLightDir)); // 按视角方向再计算一次。
					//fixed4 shadow = (_ShadowColor * (1 - shadowRange)) * _ShadowBrightness  * shadowTex + (mainTex * (1-shadowRange)) * (1-_ShadowBrightness);
					half4 shadow = half4((_ShadowColor.rgb * shadowTex * shadowRange) * _ShadowBrightness, 1)
									+ ((1 - shadowRange) * half4(1,1,1,0));

					//Get the reflect direction in world space
					fixed3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
					// get the view direction in world space
					float viewDistence = distance(_WorldSpaceCameraPos, i.worldPos); // 镜头远近调节的话，rim也要能够自动修正


					// compute specular term
					float specularRange = step((1 - _SpecularRange), dot(reflectDir, viewDir));
					fixed3 middle = _LightColor0.rgb * (1 - shadowRange) * (1 - specularRange) * _MiddleBrightness * mainTex;

					fixed4 specular = (_SpecularBrightness * _SpecularColor * specularRange) * specularTex;
					//fixed4 rimColor = (_RimRange * 2 - dot(worldNormal, viewDir) ) * _RimColor * rimTex;
					half rimFactor = (1 - max(0, dot(worldNormal, viewDir)));
					fixed4 rimColor = _RimColor * rimTex * pow(rimFactor, _RimPower) * _RimIntensity; ;
					return (fixed4(specular + ambient + middle, _SpecularColor.a) + rimColor) * mainTex * shadow;
					//return (fixed4(middle,1.0) + shadow + specular + rimColor);
					//return mainTex;
					//return (fixed4(middle, 1.0) + shadow + specular );
					//return (fixed4(_ShadowColor.a,0,0, _ShadowColor.a));
					//return shadow + middle + specular + rimColor;
					//return fixed4(specular, 1.0);
			}
			ENDHLSL
		}
						Pass
			{
				Tags{"LightMode" = "SRPDefaultUnlit"}
				Name "OUTLINEPASS"

				//ZWrite off
				cull front
				HLSLPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "UnityCG.cginc"

				struct appdata
				{
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					fixed4 color : COLOR;
				};

				struct v2f
				{
					float4 pos : SV_POSITION;
				};

				float4 _OutlineColor;
				float _OutlineWidth;

				v2f vert(appdata IN)
				{
					v2f o;
					o.pos = UnityObjectToClipPos(IN.vertex);

					float camDist = distance(mul(unity_ObjectToWorld, IN.vertex), _WorldSpaceCameraPos);

					float3 vnormal = mul((float3x3)UNITY_MATRIX_IT_MV, IN.normal);
					float2 offset = TransformViewToProjection(vnormal.xy);
					o.pos.xy += offset * camDist * _OutlineWidth * IN.color.a;
					return o;
				}

				float4 frag(v2f IN) : SV_TARGET
				{
					return _OutlineColor;
				}

				ENDHLSL
			}
		}
}
