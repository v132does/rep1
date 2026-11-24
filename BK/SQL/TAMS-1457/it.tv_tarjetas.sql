-- IT.TV_TARJETAS source

CREATE OR REPLACE FORCE EDITIONABLE VIEW "IT"."TV_TARJETAS" ("ID", "VIRTUAL_ID", "CARDHOLDER_ID", "ACCOUNT_NUMBER", "ACCOUNT_STATUS", "EXTERNAL_ACCOUNT_NUMBER", "MODALITY_CODE", "LAST_FOUR", "STATUS", "FORMAT", "EXPIRATION_DATE", "ISSUED_DATE", "ACTIVATION_DATE", "PRODUCT_ID", "IS_ADDITIONAL", "IS_VALID", "ENVELOPE_ID", "SECURED_ACCOUNT_STATUS", "TYPE") AS 
  SELECT 
       t.id, 
       t.id_virtual,
       t.cod_persona,              
       t.nro_cuenta,   
       cta.estado,          
       t.nro_cuenta, 
       cta.cod_modalidad,          
       SUBSTR(t.nro_tarjeta,-4),   
       t.cod_estado,               
       CASE WHEN t.tip_embozado IS NULL THEN (CASE WHEN t.rel_tarjeta = 0 THEN 'MV' ELSE 'MF' END) ELSE t.tip_embozado END ,             
       t.fec_vencimiento,          
       t.fec_emision,              
       t.fec_activacion,           
       t.id_producto,              
       nvl(t.rel_tarjeta,0),              
       t.vigente,                  
       embo.nro_sob_pro_principal,               
       dat_ad.val_parametro,        
       'CREDIT' type                  
FROM ta_tarjetas t
INNER JOIN ta_cta_tarjetas cta
       ON t.nro_cuenta = cta.nro_cuenta
LEFT JOIN ta_imp_dat_embozados embo
       ON t.nro_cuenta   = embo.nro_cuenta
      AND t.cod_persona  = embo.cod_persona
      AND t.nro_tarjeta  = SUBSTR(embo.nro_pan_pro_principal, 13, 4)
LEFT JOIN ge_cta_dat_adicionales dat_ad
       ON cta.nro_cuenta     = dat_ad.nro_cuenta
      AND dat_ad.parametro   = 'EST_CTA_GARANTIZADA'

UNION ALL 

SELECT h.id,  
       h.id_virtual, 
        h.cod_persona,             
       h.nro_cuenta,
       CAST(NULL AS VARCHAR2(1)),                      
       h.nro_cta_global,           
       CAST(NULL AS NUMBER),    
       h.nro_tarjeta,             
       h.cod_est_solicitud,       
       h.tip_tar_debito,          
       h.fec_vencimiento,         
       h.fec_insercion,           
       h.fec_activacion,          
       h.id_producto,             
       0,      
       h.tar_activa, 
       e.nro_sob_pro_principal,              
       CAST(NULL AS VARCHAR(4)),     
       'DEBIT'  type                 
FROM  ah_tar_debitos h
INNER JOIN ah_cta_vistas v 
        ON h.nro_cuenta=v.nro_cuenta
        AND h.cod_ent_procesadora=1175
LEFT JOIN ta_imp_dat_embozados e
        ON e.cod_persona=h.cod_persona
        AND e.nro_cta_deb_global=h.nro_cta_global
        AND substr(e.nro_pan_pro_secundario,13,4)=h.nro_tarjeta
        ;

  CREATE OR REPLACE public synonym TV_TARJETAS for IT.TV_TARJETAS;
  GRANT DELETE ON "IT"."TV_TARJETAS" TO "IT_TEMPORAL";
  GRANT SELECT ON "IT"."TV_TARJETAS" TO "IT_TEMPORAL";
  GRANT INSERT ON "IT"."TV_TARJETAS" TO "IT_TEMPORAL";
  GRANT UPDATE ON "IT"."TV_TARJETAS" TO "IT_TEMPORAL";
  GRANT SELECT ON "IT"."TV_TARJETAS" TO "IT_CONSULTAS";
  GRANT SELECT ON "IT"."TV_TARJETAS" TO "IT_DYD";
/