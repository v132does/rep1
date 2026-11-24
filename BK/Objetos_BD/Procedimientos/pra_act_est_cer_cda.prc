CREATE OR REPLACE PROCEDURE IT.PRA_ACT_EST_CER_CDA
 (P_TABLA IN VARCHAR2
  ,P_REPORTE IN VARCHAR2
  ,P_FILTRO IN VARCHAR2
 )
 IS
   v_sentencia varchar2(3000);
   v_error     varchar2(1000);
BEGIN
   if p_tabla = 'AH_CTA_CERTIFICADOS' then
     v_sentencia :=
     'declare  '||
     ' cursor c_certificado is '||
     ' select NRO_CUENTA, NRO_CERTIFICADO, rowid '||
     '  from AH_CTA_CERTIFICADOS '||
     ' where AH_CTA_CERTIFICADOS.EST_CERTIFICADO= '||''''||'C'||''''||
     '   AND AH_CTA_CERTIFICADOS.NRO_CERTIFICADO IS NOT NULL '||
     '   AND AH_CTA_CERTIFICADOS.ESTADO= '||''''||'N'||''''||     
     '   AND NOT EXISTS (SELECT 1 FROM GV_MOVIMIENTOS '||
     '                    WHERE GV_MOVIMIENTOS.COD_MODULO = AH_CTA_CERTIFICADOS.COD_MODULO '||
     '                       AND GV_MOVIMIENTOS.COD_MODALIDAD = AH_CTA_CERTIFICADOS.COD_MODALIDAD '||
     '                       AND GV_MOVIMIENTOS.NRO_CUENTA = AH_CTA_CERTIFICADOS.NRO_CUENTA '||
     '                       AND GV_MOVIMIENTOS.ESTADO != ''N'''||
     '                       AND GV_MOVIMIENTOS.REVERSADO = ''N'')';
     if fug_obt_pardinamico('VER_CUENTA', NULL, NULL, NULL, NULL) = 'N' then
        v_sentencia := v_sentencia||'   AND AH_CTA_CERTIFICADOS.ESTADO='||''''||'N'||'''';
     end if;
     v_sentencia := v_sentencia||'   and '||P_FILTRO||'; '||
     'begin '||
     ' pre_ini_aplicacion; '||
     ' pae_cnf.g_cod_modulo := 3; '||
     ' for reg in c_certificado loop '||
     '   update ah_cta_certificados '||
     '      set est_certificado = '||''''||'E'||''''||','||
     '          fec_hor_emision = pag_cal.fu_obt_fec_actual(3) '||','||
     '          cod_usu_emision = user '||
     '    where rowid = reg.rowid; '||
     '   pra_gen_mov_est_cer(reg.nro_cuenta, '||''''||'E'||''''||', reg.nro_certificado); '||
     ' end loop; '||
     'end;';
  elsif p_tabla = 'AH_CUPONES' and p_reporte = 'RGCUPCDA' then -- Impresion de cupones
     v_sentencia :=
     'declare  '||
     ' cursor c_certificado is '||
     ' select distinct AH_CTA_CERTIFICADOS.NRO_CUENTA, AH_CUPONES.NRO_CUPON, AH_CUPONES.MTO_INTERES '||
     '  from AH_CTA_CERTIFICADOS, AH_CUPONES '||
     ' where AH_CTA_CERTIFICADOS.NRO_CUENTA = AH_CUPONES.NRO_CUENTA '||
     '   and AH_CUPONES.ESTADO= '||''''||'C'||''''||
     '   and AH_CTA_CERTIFICADOS.CRE_AUTOMATICO = '||''''||'N'||''''|| -- No debe tener credito automatico
     '   and AH_CTA_CERTIFICADOS.NRO_CTA_CREDITO IS NULL '||
     '   AND AH_CTA_CERTIFICADOS.NRO_CERTIFICADO IS NOT NULL ';
     if fug_obt_pardinamico('VER_CUENTA', NULL, NULL, NULL, NULL) = 'N' then
        v_sentencia := v_sentencia||'   AND AH_CTA_CERTIFICADOS.ESTADO='||''''||'N'||'''';
     end if;
     v_sentencia := v_sentencia||
     '   and ah_cta_certificados.est_certificado = '||''''||'E'||''''||
     '   and '||P_FILTRO||'; '||
     ' v_nro_secuencia ge_movimientos.nro_secuencia%type;'||
     'begin '||
     ' pre_ini_aplicacion; '||
     ' pae_cnf.g_cod_modulo := 3; '||
     ' v_nro_secuencia := 0 ;'||
     ' for reg in c_certificado loop '||
     ' v_nro_secuencia := v_nro_secuencia + 1;'||
     '   update ah_cupones '||
     '      set estado = '||''''||'E'||''''||','||
     '          fec_hor_emision = pag_cal.fu_obt_fec_actual(3) '||
     '    where nro_cuenta = reg.nro_cuenta '||
     '      and estado = ''C''; '||
     ' end loop; '||
     'end;';
  elsif p_tabla = 'AH_CUPONES' and p_reporte = 'ALNOTCUP' then -- Nota de acreditacion
     v_sentencia :=
     'declare  '||
     ' cursor c_certificado is '||
     ' select distinct AH_CTA_CERTIFICADOS.NRO_CUENTA, AH_CUPONES.NRO_CUPON, AH_CUPONES.MTO_INTERES '||
     '  from AH_CTA_CERTIFICADOS, AH_CUPONES '||
     ' where AH_CTA_CERTIFICADOS.NRO_CUENTA = AH_CUPONES.NRO_CUENTA '||
     '   and AH_CUPONES.ESTADO= '||''''||'C'||''''||
     '   and AH_CTA_CERTIFICADOS.CRE_AUTOMATICO = '||''''||'S'||''''|| -- No debe tener credito automatico
     '   and AH_CTA_CERTIFICADOS.NRO_CTA_CREDITO IS NOT NULL '||
     '   AND AH_CTA_CERTIFICADOS.NRO_CERTIFICADO IS NOT NULL ';
     if fug_obt_pardinamico('VER_CUENTA', NULL, NULL, NULL, NULL) = 'N' then
     v_sentencia := v_sentencia||'   AND AH_CTA_CERTIFICADOS.ESTADO='||''''||'N'||'''';
     end if;
     v_sentencia := v_sentencia||
     '   and ah_cta_certificados.est_certificado = '||''''||'E'||''''||
     '   and '||P_FILTRO||'; '||
     ' v_nro_secuencia ge_movimientos.nro_secuencia%type;'||
     'begin '||
     ' pre_ini_aplicacion; '||
     ' pae_cnf.g_cod_modulo := 3; '||
     ' v_nro_secuencia := 0 ;'||
     ' for reg in c_certificado loop '||
     ' v_nro_secuencia := v_nro_secuencia + 1;'||
     '   update ah_cupones '||
     '      set estado = '||''''||'E'||''''||','||
     '          fec_hor_emision = pag_cal.fu_obt_fec_actual(3) '||
     '    where nro_cuenta = reg.nro_cuenta '||
     '      and estado = ''C''; '||
     ' end loop; '||
     'end;';


  end if;
  sql_util.ejecute_dml(v_sentencia, v_error);
  if v_error is not null then
     raise_application_error(-20000,'Act Cert.'||v_error);
  end if;
END;
/

