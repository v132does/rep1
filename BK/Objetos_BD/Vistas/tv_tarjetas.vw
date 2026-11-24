CREATE OR REPLACE FORCE EDITIONABLE VIEW "IT"."TV_TARJETAS" ("ID", "VIRTUAL_ID", "PRODUCT_CODE", "CARDHOLDER_ID", "ACCOUNT_NUMBER", "ACCOUNT_STATUS", "EXTERNAL_ACCOUNT_NUMBER", "LAST_FOUR", "STATUS", "FORMAT", "INSERT_DATE", "EXPIRATION_DATE", "ISSUED_DATE", "ACTIVATION_DATE", "UPDATED_DATE", "PRODUCT_ID", "IS_ADDITIONAL", "IS_VALID", "ENVELOPE_ID", "SECURED_ACCOUNT_STATUS", "TYPE") AS 
  SELECT 
       t.id, 
       t.id_virtual,
       tp.cod_producto, 
       t.cod_persona,              
       t.nro_cuenta,   
       cta.estado,          
       t.nro_cuenta,           
       SUBSTR(t.nro_tarjeta,-4),   
       t.cod_estado,               
       CASE WHEN t.tip_embozado IS NULL THEN (CASE WHEN t.rel_tarjeta = 0 THEN 'MV' ELSE 'MF' END) ELSE t.tip_embozado END ,             
       t.fec_insercion,
       t.fec_vencimiento,          
       t.fec_emision,              
       t.fec_activacion, 
       t.fec_modificacion,        
       t.id_producto,              
       nvl(t.rel_tarjeta,0),              
       t.vigente,                  
       embo.nro_sob_pro_principal,               
       dat_ad.val_parametro,        
       'CREDIT' type                  
FROM ta_tarjetas t
INNER JOIN ta_cta_tarjetas cta
       ON t.nro_cuenta = cta.nro_cuenta
OUTER APPLY ( SELECT p.cod_producto 
       FROM ta_productos p
       WHERE p.id_producto = t.id_producto 
       FETCH FIRST 1 ROW ONLY) tp        
LEFT JOIN ta_imp_dat_embozados embo
       ON t.nro_cuenta   = embo.nro_cuenta
      AND t.cod_persona  = embo.cod_persona
      AND SUBSTR(t.nro_tarjeta, -4)  = SUBSTR(embo.nro_pan_pro_principal, 13, 4)
LEFT JOIN ge_cta_dat_adicionales dat_ad
       ON cta.nro_cuenta     = dat_ad.nro_cuenta
      AND dat_ad.parametro   = 'EST_CTA_GARANTIZADA'


UNION ALL 

SELECT h.id,  
       h.id_virtual, 
       tp.cod_producto, 
       h.cod_persona,             
       h.nro_cuenta,
       CAST(NULL AS VARCHAR2(1)),                      
       h.nro_cta_global,    
       SUBSTR(h.nro_tarjeta,-4),             
       h.cod_est_solicitud,       
       h.tip_tar_debito, 
       h.fec_insercion,         
       h.fec_vencimiento,         
       h.fec_insercion,           
       h.fec_activacion,
       h.fec_modificacion,          
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
OUTER APPLY ( SELECT p.cod_producto 
       FROM ta_productos p
       WHERE p.id_producto = h.id_producto 
       FETCH FIRST 1 ROW ONLY) tp
LEFT JOIN ta_imp_dat_embozados e
        ON e.cod_persona=h.cod_persona
        AND e.nro_cta_deb_global=h.nro_cta_global
        AND substr(e.nro_pan_pro_secundario,13,4)=SUBSTR(h.nro_tarjeta, -4);