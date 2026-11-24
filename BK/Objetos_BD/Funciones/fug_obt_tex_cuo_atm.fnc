create or replace function it.fug_obt_tex_cuo_atm(p_cod_persona   varchar2,
                                               p_mto_solicitud varchar2)
  return varchar2 is
  v_texto          varchar2(600);
  v_char           varchar2(2) := 'N ';
  v_cuota          number;
  v_plazo          number;
  v_nro_simulacion pr_simulaciones.nro_simulacion%type;
  v_cod_moneda     pr_simulaciones.cod_moneda%type;
  v_monto          pr_simulaciones.monto%type;
  v_val_tasa       pr_simulaciones.val_tasa%type;
  v_tas_desembolso pr_simulaciones.tot_interes%type;
  v_fec_inicio     pr_simulaciones.fec_inicio%type;
  v_cotizacion     pr_simulaciones.cotizacion%type;
  v_tot_interes    pr_simulaciones.tot_interes%type;
  v_tot_cargos     pr_simulaciones.tot_cargos%type;
  v_fec_pri_vencimiento pr_simulaciones.fec_pri_vencimiento%type;
  v_linea          varchar2(100);
  v_tip_monto      varchar2(50);
  v_mto_edilicio   pr_simulaciones.mto_edilicio%type;
  v_tip_interes    ba_cod_referencias.significado%type;
begin
  --funcion para recuperar el monto de la cuota de la solicitud ofrecidas via ATM

  v_nro_simulacion := pag_pre.fu_obt_nro_simulacion(p_cod_persona, 6, 68, p_mto_solicitud);
  if v_nro_simulacion = -1 then
     raise_application_error(-20000, 'No existe solicitud para la persona ' || p_cod_persona);
  end if;
  pag_pre.pr_obt_dat_simulacion(v_nro_simulacion,
                                v_monto,
                                v_plazo,
                                v_cuota,
                                v_cod_moneda,
                                v_val_tasa,
                                v_fec_pri_vencimiento,
                                v_tas_desembolso,
                                v_fec_inicio,
                                v_cotizacion,
                                v_tot_interes,
                                v_tot_cargos,
                                v_tip_monto,
                                v_mto_edilicio,
                                v_tip_interes);             

  v_linea := v_char||'El monto del prestamo sera acreditado ';
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||'en su cta. La primera cuota vence el  ';
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||trim(to_char(v_fec_pri_vencimiento,'dd-mm-yyyy'))||'. La tasa vigente es de '||v_val_tasa||'%.';
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||'Se debitara el gasto adm. por         ';
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||'desembolso de '||fug_obt_pardinamico('COM_DES_PRESTAMO')||'% del importe.         ';
  v_texto := v_texto || rpad(v_linea,40,' ');
  /*v_linea := v_char||'Cargo IVA sobre Intereses del 10%.    ';
  v_texto := v_texto || rpad(v_linea,40,' ');*/
  v_linea := v_char||'Monto: '||trim(to_char(v_monto,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''))
             ||' Plazo: '||v_plazo;
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||'Cuota: '||trim(to_char(v_cuota,'99G999G999G990','NLS_NUMERIC_CHARACTERS = ''.,'''))
             ||' más Seg. Vida '||pag_pre.fu_obt_tas_seg_vida(68,'GS')||'%';
  v_texto := v_texto || rpad(v_linea,40,' ');
  v_linea := v_char||'Mas 10% IVA sobre interes.';
  --v_texto := v_texto || rpad(v_linea,40,' ');
  v_texto := '08'||v_texto || rpad(v_linea,38,' ')||'#G';


  return(v_texto);
end fug_obt_tex_cuo_atm;
/

