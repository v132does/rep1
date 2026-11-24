CREATE OR REPLACE FUNCTION it.fug_val_MTN910( p_referencia           in ge_snp_transferencias.nro_ref_externa%type,
                        p_cta_participante     in ge_snp_transferencias.nro_cta_pte_solicitante%type,
                        p_cta_bic_participante in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                        p_fec_valor            in ge_snp_transferencias.fec_valor%type default null
                                 )
RETURN NUMBER
IS 
   v_return NUMBER:=0;
   v_cta_bic_ueno ge_snp_transferencias.cod_swi_pte_solicitante%type;
BEGIN 
  /* Proceso para validar existencia de la referencia de un 910 antes de intentar procesar el archivo 
     Creado por TRFS-1352 PHT
     Return: 
       Mayor a 0 - Existe la referencia del MTN910
       Igual a 0 - No existe la referencia
       Menor a 0 - Se detecto algun error durante la validacion
  */    
  
    --Obtengo la cuenta BIC de Ueno
    v_cta_bic_ueno := pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad);
    
    IF p_cta_bic_participante = v_cta_bic_ueno THEN
     --El MT de referencia es enviado
         SELECT count(t.nro_referencia)
         INTO   v_return
         FROM ge_snp_transferencias t
          WHERE to_char(t.nro_referencia)    = p_referencia
            AND ( t.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Retiro / Depósito en Efectivo,
                  t.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
                )                                                     -- el Pte. Solicitante o en el Pte. Beneficiario */
            AND t.fec_valor                  = p_fec_valor
            AND t.fec_recepcion              IS NULL
            AND t.plataforma                 = 'X';
     ELSE 
     --El MT de referencia es recibidos
         SELECT count(r.nro_referencia)
         INTO   v_return
         FROM ge_snp_transferencias r
          WHERE r.nro_ref_externa            = p_referencia
            AND ( r.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Débito / Crédito Directo,
                  r.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
                )                                                     -- el Pte. Solicitante como en el Pte. Beneficiario */
            AND r.fec_valor                  = p_fec_valor
            AND r.fec_recepcion              IS NOT NULL
            AND r.plataforma                 = 'X';
			
          --TRFS-1452  
          --Si no se encuentran datos, puede ser un caso de que sea un enviado con bic distinto a ueno, se busca entonces como enviado  
          IF v_return = 0 THEN 
             SELECT count(t.nro_referencia)
             INTO   v_return
             FROM ge_snp_transferencias t
              WHERE to_char(t.nro_referencia)    = p_referencia
                AND ( t.nro_cta_pte_solicitante  = p_cta_participante OR  -- Cuando son operaciones de Retiro / Depósito en Efectivo,
                      t.nro_cta_pte_beneficiario = p_cta_participante     -- la Cuenta Física de nuestra entidad puede venir en
                    )                                                     -- el Pte. Solicitante o en el Pte. Beneficiario */
                AND t.fec_valor                  = p_fec_valor
                AND t.fec_recepcion              IS NULL
                AND t.plataforma                 = 'X';              
          END IF;			
      END IF;   
      
      RETURN v_return;
EXCEPTION WHEN OTHERS THEN
    RETURN -1;      
END fug_val_MTN910;
/
