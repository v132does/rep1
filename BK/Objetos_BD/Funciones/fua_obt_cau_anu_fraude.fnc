create or replace function it.fua_obt_cau_anu_fraude(p_nro_cuenta in varchar2,
                                                  p_cod_persona in varchar2,
                                                  p_adherente in varchar2,
                                                  p_nro_bin in varchar2) return number is
  --Proyecto SDFNVTDD-1 Vto Aleatorio de Tarjeta Debito por Fraude--	
  -- Parametro p_nro_bin agregado para obtener correctamente la TDD-SDBIN8TDD-1
  
  v_max_nro_emision ah_tar_debitos.nro_emision%type;
  v_nro_bin ge_par_entes.val_parametro%type;
  v_cod_causa ah_tar_debitos.cod_causa%type;
begin
   v_nro_bin := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD'); -- se cambia parametro de visa por Mastercard
   v_max_nro_emision := fua_obt_max_nro_emision(p_nro_cuenta, p_cod_persona, p_adherente);
   
   begin
   select b.cod_causa
     into v_cod_causa
     from ah_tar_debitos b
    where b.nro_cuenta  = p_nro_cuenta
      and b.cod_persona = p_cod_persona
      and lpad(to_char(to_number(b.adherente)),2,'0') = p_adherente
      and b.nro_emision = v_max_nro_emision
      and b.cod_causa is not null
      and b.nro_bin     = nvl(p_nro_bin, v_nro_bin)
      and b.cod_est_solicitud = 15 --Anulada para Infonet
      and exists (select 1 --Causales relacionadas a Fraude--
                    from ge_par_causales x
                   where x.cod_causa = b.cod_causa
                     and x.parametro = 'CAU_REL_FRAUDE'
                     and nvl(x.val_parametro,'N') = 'S');
    exception
      when no_data_found then
        v_cod_causa := null;
      when others then
        raise_application_error(-20002, 'Error en fua_obt_cau_anu_fraude: '||sqlerrm);
    end;    
    return (v_cod_causa);
exception
    when others then
      raise_application_error(-20002, 'Error en fua_obt_cau_anu_fraude: '||sqlerrm);
END;
/

