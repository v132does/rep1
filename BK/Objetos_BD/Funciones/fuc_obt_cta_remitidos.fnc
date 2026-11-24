CREATE OR REPLACE FUNCTION IT.FUC_OBT_CTA_REMITIDOS
 (p_nro_cheque     in cc_che_remitidos.nro_cheque%type,
  p_cod_banco      in cc_che_remitidos.cod_banco%type,
  p_cod_oficina    in cc_che_remitidos.cod_oficina%type,
  p_cod_moneda     in cc_che_rechazados.cod_moneda%type
 )
 RETURN VARCHAR2
 IS
   v_nro_cuenta     varchar2(15);
   v_cod_mon_local  cc_che_rechazados.cod_moneda%type := pag_gen.fu_obt_mon_local;
BEGIN
  
  IF nvl(p_cod_moneda, v_cod_mon_local) = v_cod_mon_local THEN
     BEGIN
       SELECT r.nro_referencia
         INTO v_nro_cuenta
         FROM cc_che_remitidos c, cc_che_remitidos_res r, ge_cuentas g
        WHERE c.nro_cheque = p_nro_cheque
          AND c.cod_banco = p_cod_banco
          AND c.cod_cau_devolucion is null
          AND c.cod_oficina = p_cod_oficina
          AND c.fecha = (SELECT max(fecha) --Porque pueden haber varias devoluciones
                           FROM cc_che_remitidos
                          WHERE cod_banco = p_cod_banco
                            AND nro_cheque = p_nro_cheque
                            AND cod_cau_devolucion is null
                            AND cod_oficina = p_cod_oficina)
          AND c.fecha = r.fecha
          AND c.cod_oficina = r.cod_oficina
          AND c.nro_lote = r.nro_lote
          AND g.nro_cuenta = r.nro_referencia
          AND nvl(fug_obt_pardinamico('MOD_CHE_DEVUELTOS', g.cod_modulo, g.cod_modalidad), 'N') = 'S';   
     EXCEPTION
       WHEN OTHERS THEN
         v_nro_cuenta := null;
     END;                    
  ELSE
     BEGIN  
       SELECT nro_cuenta
         INTO v_nro_cuenta
         FROM cc_che_enviados
        WHERE nro_cheque = p_nro_cheque
          AND cod_banco = p_cod_banco
          AND estado <> 'D'          
          AND fecha = (SELECT MAX(fecha) --agregado xq puede haber varias devoluciones
                         FROM cc_che_enviados
                        WHERE cod_banco = p_cod_banco
                          AND estado <> 'D'
                          AND nro_cheque = p_nro_cheque);
     EXCEPTION
       WHEN OTHERS THEN 
         v_nro_cuenta := null;
     END;
     pag_cta.pr_obt_cuenta(v_nro_cuenta);
     IF nvl(fug_obt_pardinamico('MOD_CHE_DEVUELTOS', pag_cta.g_ctas.cod_modulo, pag_cta.g_ctas.cod_modalidad), 'N') <> 'S' THEN
        v_nro_cuenta := null;
     END IF;                     
  END IF;

  return v_nro_cuenta;

EXCEPTION
   WHEN OTHERS THEN
     if sqlcode < -20000  then
         raise;
     else
        raise_application_error(-20000,'Error en FUC_OBT_CTA_REMITIDOS : ' || sqlerrm);
     end if;
END;
/

