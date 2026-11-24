create or replace function it.fup_ver_lim_cob_seguro(p_cod_persona in varchar2,
                                                  p_cod_ent_seguro in number,
                                                  p_nro_solicitud in number default null,
                                                  p_cod_mon_nvo_prestamo in varchar2 default null,
                                                  p_mto_nvo_prestamo in number default null) return varchar2 is  
  -----------------------------------------------------------
  --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)----
  --Devuelve mens. de advertencia si el cliente sobrepasa----
  --monto techo para la cobertura del Seg Vida por Cliente---
  -----------------------------------------------------------
  v_msj_con_cob_seguro varchar2(4000);
  v_mto_lim_cob_seg_vida number(18,2);
  v_mto_deu_sal_cliente number(18,2);
  v_cod_mon_local ba_monedas.cod_moneda%type;
  v_sal_capital number(18,2);
  v_mto_con_cob_seguro number(18,2);
  v_cod_mon_nvo_prestamo ba_monedas.cod_moneda%type;
  v_mto_nvo_prestamo number(18,2);

begin
  --Validaciones de los parametros de entrada--
  IF p_cod_persona is null then
     raise_application_error(-20000,'Error. Parametros de codigo de persona no puede ser nulo. Verifique.');
  elsif p_cod_ent_seguro is null then
     raise_application_error(-20000,'Error. Parametros de ente de seguro no puede ser nulo. Verifique.');
  elsif ((p_nro_solicitud IS NOT NULL) AND ((p_cod_mon_nvo_prestamo IS  NOT NULL) or (p_mto_nvo_prestamo is not null))) THEN
     raise_application_error(-20000,'Error en envio de parametros. Verifique.');
  elsif ((p_nro_solicitud IS NULL) AND ((p_cod_mon_nvo_prestamo IS NULL) or (p_mto_nvo_prestamo is null))) THEN
     raise_application_error(-20000,'Error en envio de parametros. Verifique.');
  END IF;

  --Carga de Variables--
  v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
  v_msj_con_cob_seguro := null;
  v_mto_lim_cob_seg_vida := fug_obt_pardinamico('MTO_LIM_COB_SEG_VIDA',null,null,v_cod_mon_local,null,null);
  v_mto_con_cob_seguro := 0;

  --Buscar los datos del Cliente--
  select sum(nvl(fub_con_mon_a_moneda(a.cod_moneda, v_cod_mon_local, a.sal_capital),0))
    into v_sal_capital
    from pr_cta_prestamos a, pr_sol_cargos b, ge_cta_clientes c, ge_entes d
   where b.cod_ent_seguro is not null
     and b.nro_solicitud = a.nro_solicitud
     and a.estado <> 'N'
     and c.nro_cuenta = a.nro_cuenta
     and c.relacion = 'P'
     and c.cod_persona = p_cod_persona
     and p_nro_solicitud <> a.nro_solicitud
     and nvl(a.sal_capital,0) > 0
     and b.cod_transaccion = 1521 --TRansaccion de Seguro de Vida--
     and d.cod_ente = b.cod_ent_seguro
     and exists (select 1 from ge_entes x
                  where x.cod_persona = d.cod_persona
                    and x.cod_ente = p_cod_ent_seguro);

  if p_nro_solicitud is not null then
     begin
       select k.cod_moneda, k.monto
         into v_cod_mon_nvo_prestamo, v_mto_nvo_prestamo
         from pr_solicitudes k
        where k.nro_solicitud = p_nro_solicitud;
        v_mto_deu_sal_cliente := nvl(v_sal_capital,0) +
                                fub_con_mon_a_moneda(v_cod_mon_nvo_prestamo, v_cod_mon_local, v_mto_nvo_prestamo);
      exception
        when others then
             v_cod_mon_nvo_prestamo := null;
             v_mto_nvo_prestamo := 0;
      end;
  else
     v_mto_deu_sal_cliente := nvl(v_sal_capital,0) +
                              fub_con_mon_a_moneda(p_cod_mon_nvo_prestamo, v_cod_mon_local, p_mto_nvo_prestamo);
  end if;
  v_mto_con_cob_seguro := nvl(v_mto_lim_cob_seg_vida,0) - nvl(v_mto_deu_sal_cliente,0);

  --Validacion si sobrepasa monto de Parametro--
  if nvl(v_mto_con_cob_seguro,0) < 0 then
     v_msj_con_cob_seguro := 'Atencion: Cliente '||p_cod_persona||'-'||fue_obt_nom_persona(p_cod_persona)||' '||
                             'sobrepasa en '||v_cod_mon_local||' '||trim(to_char(abs(v_mto_con_cob_seguro),'999,999,999,999.00'))||CHR(13)||
                             'la cobertura por cliente del Seguro de Vida '||p_cod_ent_seguro||'-'||fue_obt_nom_ente(p_cod_ent_seguro)||chr(13)||
                             'Parametro Bco '||v_cod_mon_local||' '||trim(to_char(abs(v_mto_lim_cob_seg_vida),'999,999,999,999.00'))||' '||
                             'Deuda total cliente '||v_cod_mon_local||' '||trim(to_char(abs(v_mto_deu_sal_cliente),'999,999,999,999.00'));

  end if;
  --Retorna Mesnaje, si esta cargado tiene mensaje de advertencia--
  return v_msj_con_cob_seguro;
exception
    when others then
         raise_application_error(-20000,'Error en fup_ver_lim_cob_seguro(p_cod_persona: '||sqlerrm);
end;
/

