create or replace procedure it.prg_imp_act_esperadas
is
  v_mto_pro_debito cr_act_esperadas.mto_pro_debito%type;
  v_mto_pro_credito cr_act_esperadas.mto_pro_credito%type;
  v_cod_persona cr_act_esperadas.cod_persona%type;
  v_cod_moneda cr_act_esperadas.cod_moneda%type := 'GS';
  v_cotizacion ge_cotizaciones.val_conversion%type;
  v_fec_actual ge_calendarios.fec_actual%type := pae_cnf.FU_OBT_FEC_ACTUAL(1);
 
  --valores duplicados que serán modificados, si coinciden en fecha
  /*
  esta lista traera los perfiles que ya estan en la tabla de actividades esperadas,
  porque fueron cargadas via la interfaz de Perfiles de Clientes,
  en estos casos
  */
  -- 
  cursor act is
  select cod_persona,
         cod_moneda,
         to_number(can_tra_debito) can_tra_debito,
         to_number(can_tra_credito) can_tra_credito,
         to_number(mto_pro_debito) mto_pro_debito,
         to_number(mto_pro_credito) mto_pro_credito,
         v_fec_actual as fecha
    from cr_act_esperadas_tmp;

begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --
  for a in act loop
    v_cod_persona := substr(a.cod_persona,3);
    --
    begin
      select round(c.val_conversion * a.mto_pro_debito),round(c.val_conversion * a.mto_pro_credito), c.val_conversion
        into v_mto_pro_debito, v_mto_pro_credito, v_cotizacion
        from ge_cotizaciones c
       where c.fecha = a.fecha
         and c.cod_moneda = a.cod_moneda;
    exception 
      when no_data_found then
         raise_application_error(-20000,'No Existe cotización para fecha '||to_char(a.fecha,'dd/mm/yyyy'));
      when others then null; 
    end;
    if v_cotizacion is not null then  
    --
      begin
        insert into cr_act_esperadas
          (cod_persona, cod_moneda, can_tra_debito, can_tra_credito, mto_pro_debito, mto_pro_credito, fecha)
        values
          (v_cod_persona, v_cod_moneda, a.can_tra_debito, a.can_tra_credito, v_mto_pro_debito, v_mto_pro_credito, a.fecha);
      exception
        when DUP_VAL_ON_INDEX then
             update cr_act_esperadas
             set can_tra_debito = a.can_tra_debito, 
                 can_tra_credito = a.can_tra_credito, 
                 mto_pro_debito =  v_mto_pro_debito, 
                 mto_pro_credito = v_mto_pro_credito 
              where cod_persona = v_cod_persona and fecha = a.fecha;
        when others then
             RAISE_APPLICATION_ERROR(-20001,'Error al insertar Actividad Esperada. '||sqlerrm);
      end;
    end if;
  end loop;
  --select * from cr_act_esperadas where usu_insercion = 'IT' and trunc(fec_insercion) = trunc(sysdate)
  -- delete cr_act_esperadas_tmp
end;
/

