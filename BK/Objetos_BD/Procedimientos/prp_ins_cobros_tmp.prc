CREATE OR REPLACE PROCEDURE IT.PRP_INS_COBROS_TMP
 (P_COD_PERSONA IN VARCHAR2
 ,P_FILTROS IN OUT VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 ,P_FECHA IN DATE
 )
 IS
v_sentencia varchar2(3000);
v_error varchar2(1000);
BEGIN
   v_sentencia := 'declare v_retorno number(18,2) := 0;  v_retorno2 varchar(60);'||
   'cursor cta_cuotas is '||
   'select pr_cuotas.nro_cuenta,'||
   '    min(pr_cuotas.nro_cuota) cuo_desde,'||
   '    max(pr_cuotas.nro_cuota) cuo_hasta'||
' from ge_cta_clientes,'||
 '     pr_cta_prestamos,'||
  '    pr_cuotas '||
'where ge_cta_clientes.nro_cuenta = pr_cta_prestamos.nro_cuenta '||
' and ge_cta_clientes.relacion = '||''''||'P'||''''||
' and pr_cta_prestamos.nro_cuenta = pr_cuotas.nro_cuenta'||
' and pr_cta_prestamos.estado != '||''''||'N'||''''||
' and pr_cuotas.estado != '||''''||'N'||''''||
' and pr_cuotas.nro_cuota > 0'||
-----' and pr_cuotas.fec_vencimiento < TO_DATE('||''''||to_char(NVL(P_FECHA,SYSDATE),'dd/mm/rrrr')||''''||','||''''||'DD/MM/RRRR'||''''||')'||
' and ge_cta_clientes.cod_persona = '||nvl(P_COD_PERSONA,'ge_cta_clientes.cod_persona')
||' and ge_cta_clientes.nro_cuenta = '||nvl(P_NRO_CUENTA,'ge_cta_clientes.nro_cuenta');
 v_sentencia := v_sentencia||'   and '||nvl(P_FILTROS,'1=1')||'group by pr_cuotas.nro_cuenta;'||
'begin '||
   'PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 6; '||
  ' for cc in cta_cuotas loop'||
  '  pap_pre.pr_ini_autorizacion; '||
   ' pap_pre.pr_obt_deu_prestamo(cc.nro_cuenta,'||
            'TO_DATE('||''''||to_char(NVL(P_FECHA,pag_cal.FU_OBT_FEC_ACTUAL(1)),'dd/mm/rrrr')||''''||','||''''||'DD/MM/RRRR'||''''||')'||','||
            'cc.cuo_desde,'||
             999||','||   --                   'cc.cuo_hasta,'||
            'null,'|| --vcp_cod_ofi_origen,
            'null,'|| --:cp_mto_cobrado,
            'v_retorno2,'|| --vcp_error, -- p_error
            'v_retorno2,'|| --vcp_mensaje, -- p_mensaje
            'v_retorno,'|| --vcp_tot_capital,
            'v_retorno,'|| --vcp_tot_interes,
            'v_retorno,'|| --vcp_tot_int_adelantado,
            'v_retorno,'|| --vcp_tot_mora,
            'v_retorno,'|| --vcp_tot_mora_interes,
            'v_retorno,'|| --vcp_tot_mora_int_ade,
            'v_retorno,'|| --vcp_tot_punitorio,
            'v_retorno,'|| --vcp_tot_impuesto,
            'v_retorno,'|| --vcp_tot_cargo,
            'v_retorno,'|| --vcp_tot_cargo_iva,
            'v_retorno,'|| --vcp_tot_int_descontado,
            'v_retorno,'|| -- p_dia_mora
            'null,'|| --null,
            'null'|| --null
            ');'||

 'end loop; '||
  'COMMIT;'||
 '  end;';

  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Error al insertar en pr_cobros_tmp'||v_error);
  end if;
END;
/

