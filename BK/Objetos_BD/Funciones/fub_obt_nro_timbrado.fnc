create or replace function it.fub_obt_nro_timbrado(p_tipo in varchar2,
                                                p_cod_oficina IN ba_oficinas.cod_oficina%TYPE DEFAULT NULL) return varchar2 IS
  v_nro_timbrado cb_lib_ventas.nro_timbrado%type;
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(2);
  v_ofi_pto_generico ba_oficinas.cod_oficina%TYPE := NVL(fug_obt_pardinamico('CON_OFI_PTO_EXP_GENERICO'),'-1');
  v_cod_oficina      ba_oficinas.cod_oficina%TYPE := p_cod_oficina;
BEGIN
  --Oficina Genérica
  IF v_ofi_pto_generico <> -1 THEN
     v_cod_oficina := v_ofi_pto_generico;
  END IF;
  
  select c.nro_timbrado
    into v_nro_timbrado
     from cb_par_comprobantes c
    where cod_oficina = v_cod_oficina
      and tipo = p_tipo
      and fec_vencimiento >= v_fec_actual
      and fec_vencimiento =
          (select max(fec_vencimiento)
             from cb_par_comprobantes t
            where t.cod_oficina = c.cod_oficina
              and t.tipo = c.tipo
              and (nro_desde+cantidad) > nvl(ult_nro_emitido + 1, nro_desde));
   return v_nro_timbrado;
exception
  when others then
    raise_application_error(-20000, 'Error en Obtener Nro. de Timbrado, Oficina: '||v_cod_oficina||' Verifique.-' || sqlerrm);
END;
/

