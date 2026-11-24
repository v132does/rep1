CREATE OR REPLACE PROCEDURE IT.PRG_ACT_GRU_ECO_CLIENTES(p_cod_persona          in varchar2,
                                                     p_cod_gru_eco_anterior in number default null,
                                                     p_cod_gru_eco_nuevo    in number default null) is

v_nro_lin_gru_ant         pr_gru_lineas.nro_linea%type;
v_nro_lin_gru_nuevo       pr_gru_lineas.nro_linea%type;
v_cod_moneda              pr_lineas.cod_moneda%type;
v_mto_aplicado            pr_lineas.mto_aplicado%type;
v_can_clientes            number(9);

  procedure lp_act_aplicaciones(p_cod_persona in varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
    delete from pr_gru_lin_aplicaciones where cod_persona = p_cod_persona;
    commit;
  exception
    when others then
      null;
  end;
  
  procedure lp_ins_aplicaciones(p_nro_lin_gru_nuevo  pr_gru_lin_aplicaciones.nro_linea%type,
                                p_cod_gru_eco_nuevo  pr_gru_lin_aplicaciones.cod_gru_economico%type,
                                p_cod_persona        pr_gru_lin_aplicaciones.cod_persona%type,
                                p_cod_moneda         pr_gru_lin_aplicaciones.cod_moneda%type,
                                p_mto_aplicado       pr_gru_lin_aplicaciones.mto_aplicado%type) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
    insert into pr_gru_lin_aplicaciones
      (nro_linea, cod_gru_economico, cod_persona, cod_moneda, mto_aplicado)
    values
      (p_nro_lin_gru_nuevo, p_cod_gru_eco_nuevo, p_cod_persona, p_cod_moneda,p_mto_aplicado);
     commit;
  exception
    when others then
      raise_application_error(-20001,
                              'Cliente: ' || p_cod_persona ||
                              'Error al Ins. Aplicación de Límite por Grupo' ||
                              sqlerrm);
  end;
  
Begin
  
 begin
 
  if p_cod_gru_eco_anterior is not null then
     ---Obtiene numero de linea del grupo
     begin     
        select r.nro_linea
          into v_nro_lin_gru_ant
          from pr_gru_lineas r
         where r.cod_gru_economico = p_cod_gru_eco_anterior
           and r.estado = 'A';
     exception
        when others then
          null;
     end;
    if v_nro_lin_gru_ant is not null then
        lp_act_aplicaciones(p_cod_persona);
    end if;
  end if;
exception
  when no_data_found then
  null;
  when others then
   raise_application_error(-20002,'Cliente: '||p_cod_persona||'- Error al Act. Límite por Grupo'||sqlerrm);

end;

begin
  if p_cod_gru_eco_nuevo is not null then
    ---Obtiene numero de linea del grupo
    begin
      select r.nro_linea
        into v_nro_lin_gru_nuevo
        from pr_gru_lineas r
       where r.cod_gru_economico = p_cod_gru_eco_nuevo
         and r.estado = 'A';
    exception
      when others then
        null;
    end;   
   if v_nro_lin_gru_nuevo is not null then  
    ---Obtiene moneda de la linea 
    begin
      select li.cod_moneda, li.mto_aplicado
        into v_cod_moneda, v_mto_aplicado
        from pr_lineas li
       where li.cod_persona = p_cod_persona
         and li.estado in ('A', 'B', 'V');
    exception
      when others then
        null;
    end;

   
      if v_cod_moneda is not null then
         lp_act_aplicaciones(p_cod_persona);
         lp_ins_aplicaciones(v_nro_lin_gru_nuevo, p_cod_gru_eco_nuevo, p_cod_persona, v_cod_moneda, v_mto_aplicado);
     end if;

    end if;
  end if;
exception
  when no_data_found then
  null;
  when others then
   raise_application_error(-20002,'Cliente: '||p_cod_persona||'- Error al Act. Límite por Grupo'||sqlerrm);

end;  

exception
  when no_data_found then
     null;
  when others then
    raise_application_error(-20002,'Cliente: '||p_cod_persona||'- Error al Act. Límite por Grupo'||sqlerrm);

end PRG_ACT_GRU_ECO_CLIENTES;
/

