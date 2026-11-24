CREATE OR REPLACE FUNCTION IT.fup_inc_ope_medida
(
   p_cod_persona IN ge_clientes.cod_persona%TYPE,
   p_nro_cuenta  IN ge_cta_clientes.nro_cuenta%TYPE
) RETURN VARCHAR2 IS
   v_incluir     VARCHAR2(1);
   -- v_fec_proceso DATE := pag_cal.fu_obt_fec_actual(6);
BEGIN
   ---incluir el prestamo de medida transitoria solo si supera la categoría del cliente.
   --- y no tiene otro tipo de operacion 
   SELECT DISTINCT 'S'
     INTO v_incluir
     FROM ge_cla_operaciones s
    WHERE cod_persona = p_cod_persona
      AND s.nro_cuenta = p_nro_cuenta
      AND ( /*(s.cat_automatica >
                              pap_cat.fu_obt_cat_cliente(s.cod_persona,
                                                           pag_cal.fu_obt_fec_ant_hab(v_fec_proceso, 1, 1)) AND*/
           --1
           (EXISTS (SELECT 1
                     FROM ge_par_dinamicos p
                    WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      AND p.cod_modalidad = s.cod_modalidad
                      AND p.cod_modulo = s.cod_modulo
                      AND nvl(p.val_parametro, 'N') = 'S') AND NOT EXISTS
           (SELECT 1 -- todos los miembros tienen solo ope de ME.
              FROM ge_cla_operaciones s
             WHERE s.cod_persona = p_cod_persona
               AND NOT EXISTS (SELECT 1
                      FROM ge_par_dinamicos p
                     WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                       AND p.cod_modalidad = s.cod_modalidad
                       AND p.cod_modulo = s.cod_modulo
                       AND nvl(p.val_parametro, 'N') = 'S'))) OR --no es de medida transitoria
           --2
           (NOT EXISTS (SELECT 1
                         FROM ge_par_dinamicos p
                        WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          AND p.cod_modalidad = s.cod_modalidad
                          AND p.cod_modulo = s.cod_modulo
                          AND nvl(p.val_parametro, 'N') = 'S')
                 AND NOT EXISTS (SELECT 1
                                   FROM ge_cta_dat_adicionales a 
                                  WHERE a.parametro IN ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                    AND a.nro_cuenta = s.nro_cuenta)) OR 
           --3
           (NOT EXISTS (SELECT 1
                         FROM ge_par_dinamicos p
                        WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          AND p.cod_modalidad = s.cod_modalidad
                          AND p.cod_modulo = s.cod_modulo
                          AND nvl(p.val_parametro, 'N') = 'S') 
                       AND EXISTS (select 1
                                 from ge_cta_dat_adicionales a 
                                where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and a.nro_cuenta = s.nro_cuenta)
                       AND NOT EXISTS (SELECT 1 -- todos los miembros tienen solo ope de ME.
                               FROM ge_cla_operaciones xx
                              WHERE xx.cod_persona = p_cod_persona
                                 AND xx.nro_cuenta <> s.nro_cuenta
                                 AND 'N' = (SELECT nvl(max(pp.val_parametro), 'N')
                                            FROM ge_par_dinamicos pp
                                           WHERE pp.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                             AND pp.cod_modalidad = xx.cod_modalidad
                                             AND pp.cod_modulo = xx.cod_modulo))) 
            );

   RETURN v_incluir;
EXCEPTION
   WHEN no_data_found THEN
      RETURN 'N';
   WHEN OTHERS THEN
      RETURN 'N';
END;
/
