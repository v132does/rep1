create or replace function it.fua_ver_tar_anu_fraude(p_nro_cuenta in varchar2,
                                                  p_cod_persona in varchar2,
                                                  p_adherente in varchar2,
                                                  p_nro_bin   in varchar2) return varchar2 is
  --Proyecto SDFNVTDD-1 Vto Aleatorio de Tarjeta Debito por Fraude--
  -- Parametro p_nro_bin agregado para obtener correctamente la TDD-SDBIN8TDD-1
  --Variables--
  v_max_nro_emision ah_tar_debitos.nro_emision%type;
  v_nro_bin ge_par_entes.val_parametro%type;
  v_tie_tar_anu_fraude varchar2(1);
begin
  v_nro_bin := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD');  -- se cambia parametro de Visa por Mastercard
  v_max_nro_emision := fua_obt_max_nro_emision(p_nro_cuenta, p_cod_persona, p_adherente);
  v_tie_tar_anu_fraude := 'N';
  
  select decode(nvl(count(*),0),0,'N','S')
    into v_tie_tar_anu_fraude
    from ah_tar_debitos b
   where b.nro_cuenta  = p_nro_cuenta
     and b.cod_persona = p_cod_persona
     and lpad(to_char(to_number(b.adherente)),2,'0') = p_adherente
     and b.nro_emision = v_max_nro_emision
     and b.nro_bin     = nvl(p_nro_bin, v_nro_bin)
     and b.cod_est_solicitud = 15 --Anulada para Infonet
     and exists (select 1 --Causales relacionadas a Fraude--
                   from ge_par_causales x
                  where x.cod_causa = b.cod_causa
                    and x.parametro = 'CAU_REL_FRAUDE'
                    and nvl(x.val_parametro,'N') = 'S');
   
     return v_tie_tar_anu_fraude;
exception
    when others then
      raise_application_error(-20002, 'Error en fua_ver_tar_anu_fraude: '||sqlerrm);
end;
/

