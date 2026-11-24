create or replace function it.fua_obt_max_nro_emision(p_nro_cuenta in varchar2,
                                                   p_cod_persona in varchar2,
                                                   p_adherente in varchar2) return varchar2 is
  --Proyecto SDFNVTDD-1 Vto Aleatorio de Tarjeta Debito por Fraude--											   
  v_nro_emision ah_tar_debitos.nro_emision%type;
  v_nro_bin ge_par_entes.val_parametro%type;
begin
  v_nro_bin := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TAR_DEBITO');
  select lpad(to_char(nvl(max(to_number(nro_emision)),0)),2,'0')
    into v_nro_emision
    from ah_tar_debitos b
   where b.nro_cuenta  = p_nro_cuenta
     and b.cod_persona = p_cod_persona
     and lpad(to_char(to_number(b.adherente)),2,'0') = p_adherente
     and b.nro_bin     = v_nro_bin;
  return (v_nro_emision);
exception
    when others then
      raise_application_error(-20002, 'Error en fua_obt_max_nro_emision: '||sqlerrm);
END;
/

