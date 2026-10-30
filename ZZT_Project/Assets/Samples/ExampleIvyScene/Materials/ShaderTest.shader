Shader "CRLuo/CRLuo_Teaching05_RampColor3_FB_URP"
{
    Properties
    {
        [Header(Front Side)]
        _ColorH_F("正面亮部颜色",Color)=(1,1,0.5,1)
        _ColorM_F("正面灰部颜色",Color)=(0,1,0,1)
        _ColorL_F("正面暗部颜色",Color)=(0,0.1,0.1,1)
        
        [Header(Back Side)]
        _ColorH_B("背面亮部颜色",Color)=(1,1,0.5,1)
        _ColorM_B("背面灰部颜色",Color)=(0.5,0.5,0,1)
        _ColorL_B("背面暗部颜色",Color)=(0.1,0,0,1)

        [Header(Main Texture)]
        _MainTex("贴图", 2D) = "white" {}
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        CBUFFER_START(UnityPerMaterial)
            half4 _ColorH_F;
            half4 _ColorM_F;
            half4 _ColorL_F;
            half4 _ColorH_B;
            half4 _ColorM_B;
            half4 _ColorL_B;
            float4 _MainTex_ST;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "RampColor"
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            
            // 添加VFACE支持
            #pragma shader_feature_local _ _DOUBLE_SIDED_ON

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float fogFactor : TEXCOORD1;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
                #if defined(_DOUBLE_SIDED_ON)
                    float facing : VFACE;
                #endif
            };

            v2f vert(appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                // 计算雾效因子
                o.fogFactor = ComputeFogFactor(o.vertex.z);
                
                #if defined(_DOUBLE_SIDED_ON)
                    // 双面渲染时计算面朝向
                    o.facing = dot(UNITY_MATRIX_IT_MV[2].xyz, v.vertex.xyz) > 0 ? 1 : -1;
                #endif
                
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                // 采样贴图
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                
                // 透明裁切
                clip(col.a - 0.5);
                
                // 根据VFACE值选择颜色组
                half4 colorH, colorM, colorL;
                
                #if defined(_DOUBLE_SIDED_ON)
                    if (i.facing > 0) // 正面
                    {
                        colorH = _ColorH_F;
                        colorM = _ColorM_F;
                        colorL = _ColorL_F;
                    }
                    else // 背面
                    {
                        colorH = _ColorH_B;
                        colorM = _ColorM_B;
                        colorL = _ColorL_B;
                    }
                #else
                    // 单面渲染只使用正面颜色
                    colorH = _ColorH_F;
                    colorM = _ColorM_F;
                    colorL = _ColorL_F;
                #endif
                
                // 计算灰度值
                half gray = dot(col.rgb, half3(0.299, 0.587, 0.114));
                
                // 根据灰度值混合颜色
                half3 colorLow = lerp(colorL.rgb, colorM.rgb, saturate(gray * 2));
                half3 colorHigh = lerp(colorM.rgb, colorH.rgb, saturate((gray - 0.5) * 2));
                half3 finalColor = lerp(colorLow, colorHigh, gray);
                
                // 应用雾效
                finalColor = MixFog(finalColor, i.fogFactor);
                
                return half4(finalColor, col.a);
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Unlit"
}