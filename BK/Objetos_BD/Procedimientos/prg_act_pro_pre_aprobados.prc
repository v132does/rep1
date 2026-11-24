create or replace procedure it.prg_act_pro_pre_aprobados is
/**
  --- Author  : CNOGUERA
  -- Created : 20/01/2015
  --- Purpose : Procedimiento que se ejecutará en el Inicio de Día en el Core que
               evaluará si el Pre-Aprobado está habilitado para Desembolso en ATM.
**/
 v_cod_persona ge_pro_pre_aprobados.cod_persona%type;
 v_id          varchar2(21);
 v_fec_actual      date:= pag_cal.FU_OBT_FEC_ACTUAL(6);
 cursor c_cursor is
   select distinct a.cod_persona,a.rowid id
      from ge_pro_pre_aprobados a
      where a.estado = 'V'
       and nvl(fug_obt_pardinamico('MOD_PRE_APR_ATM_WEB',a.cod_modulo,a.cod_modalidad),'N') = 'S'  -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- 10/2016 --
       and a.nro_solicitud is null
       and (a.plz_12_meses is not null or a.plz_18_meses is not null or a.plz_24_meses is not null or a.plz_30_meses is not null or
            a.plz_36_meses is not null or a.plz_42_meses is not null or a.plz_48_meses is not null or a.plz_54_meses is not null or
            a.plz_60_meses is not null)
       and ( a.cod_campana in( select distinct c.cod_campana
                                 from cr_campanas c
                                where v_fec_actual >= c.fec_inicio
                                  and ( v_fec_actual <= c.fec_vencimiento or c.fec_vencimiento is null )
                              )
             or a.cod_campana is null );


  function lf_ver_cli_nomina(p_cod_persona varchar2)
    return varchar2 is
    v_exi_ente varchar2(1) := 'N';
    begin
      Select 'S'
        into v_exi_ente
        from ge_cta_clientes pe
       where pe.cod_persona = p_cod_persona
         and (exists
       (Select 1
                from ah_cta_vistas ah, ge_cta_clientes cl, ge_est_cuentas g
               where cl.nro_cuenta = ah.nro_cuenta
                 and cl.cod_persona = pe.cod_persona
                 and cl.cod_modulo = g.cod_modulo
                 and cl.cod_modalidad = g.cod_modalidad
                 and ah.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion = 'P'
                 and ah.cod_ente is not null
                 and (ah.nro_cuenta = pe.nro_cuenta or pe.nro_cuenta is null))
          or exists
       (Select 1
                from cc_cta_corrientes cc, ge_cta_clientes cl, ge_est_cuentas g
               where cc.nro_cuenta = cl.nro_cuenta
                 and cl.cod_persona = pe.cod_persona
                 and cl.cod_modulo = g.cod_modulo
                 and cl.cod_modalidad = g.cod_modalidad
                 and cc.estado = g.estado
                 and g.activo = 'S'
                 and cl.relacion = 'P'
                 and cc.cod_ente is not null
                 and (cc.nro_cuenta = pe.nro_cuenta or pe.nro_cuenta is null)));
      return v_exi_ente;
    exception
      when too_many_rows then
        v_exi_ente := 'S'; ---Indica que SI existe ente en cuentas del cliente.
        return v_exi_ente;
      when no_data_found then
        v_exi_ente := 'N'; --Indica que NO existe ente en cuentas del cliente.
        return v_exi_ente;
      when others then
        v_exi_ente := 'N'; --Indica que NO existe ente en cuentas del cliente.
        return v_exi_ente;
    end lf_ver_cli_nomina;
  --
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  /**
  Se actualiza el campo IND_HAB_ATM de la tabla GE_PRO_PRE_APROBADOS a 'N',
  para todos los Pre-Aprobados con estado = 'V', modulo 6 y modalidad 68.
  **/
  --se habilita por la importacion de area de negocios
  /*update ge_pro_pre_aprobados a
     set a.ind_hab_atm = 'N'
   where a.estado = 'V'
     and a.cod_modulo = 6
     and a.cod_modalidad = 68
     and a.nro_solicitud is null; */

  if c_cursor%isopen then
     close c_cursor;
  end if;
  open c_cursor;
  loop
    fetch c_cursor into v_cod_persona,v_id;
    exit when c_cursor%notfound;
    /**
    Se evalua si los Pre-Aprobados cumplen las condiciones para ser habilitadas
    para desembolso en ATM.
    **/
	--Se excluye validacion de si es cliente nomina (Flexibilidad) 16_05_2017
    if fut_val_req_pre_aprobados(v_cod_persona,'N') /*and lf_ver_cli_nomina(v_cod_persona) = 'S'*/ then
      /**
      Devolverá un valor true si está habilitado para el desembolso en el ATM.
      En este caso se actualiza el campo IND_HAB_ATM a 'S' en la tabla GE_PRO_PRE_APROBADOS.
      **/
      update ge_pro_pre_aprobados a
         set a.ind_hab_atm = 'S',
             a.ind_hab_hb  = 'S'
       where a.cod_persona = v_cod_persona
         and a.rowid       = v_id;
    else
      --No cumple las condiciones
      update ge_pro_pre_aprobados a
         set a.ind_hab_atm = 'N',
             a.ind_hab_hb  = 'N'
       where a.cod_persona = v_cod_persona
         and a.rowid       = v_id;
    end if;
  end loop;

  if c_cursor%isopen then
     close c_cursor;
  end if;

exception
  when others then
    Raise_application_error(-20000, 'Error en el Procedimiento prg_act_pro_pre_aprobados: '||sqlerrm);
end;
/

