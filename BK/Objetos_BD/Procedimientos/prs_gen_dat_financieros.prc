create or replace procedure it.PRS_GEN_DAT_FINANCIEROS is
vg_fec_actual      ge_calendarios.fec_actual%TYPE;
vg_gru_eco_entidad ge_clientes.cod_gru_economico%TYPE;
vg_hor_inicio      varchar2(8);
vg_hor_fin         varchar2(8);
vg_lugar           varchar2(100);
vg_cod_programa    ge_log_procesos.cod_programa%type;
--Limpia tablas temporales
procedure LP_PRE_TABLAS is --modificar LP ELI TRU DATOS
begin
  vg_lugar      := 'LP_PRE_TABLAS';
 	vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  -- elimina registro de la fecha, para casos de reproceso
  delete from SB_DAT_FINANCIEROS where fecha = vg_fec_actual;
  -- trunca tablas temporales
  execute immediate 'truncate table SB_DAT_FIN_CREDITOS_TMP';
  execute immediate 'truncate table SB_DAT_FIN_RUB_INFORME_TMP';
  execute immediate 'truncate table SB_DAT_FIN_PERSONAS_TMP';
  execute immediate 'truncate table SB_DAT_FIN_RUB_ECONOMICOS_TMP';
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
 	prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_PRE_TABLAS;
--Inserta Creditos Vigentes y Vencidos
procedure LP_INS_CREDITOS_TMP is
begin
  vg_lugar      := 'LP_INS_CREDITOS_TMP';
 	vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  -- recupera el ultimo registro de rubro economico de la operación
  insert into SB_DAT_FIN_RUB_ECONOMICOS_TMP (NRO_OPERACION, COD_RUB_ECONOMICO, FECHA)
  select distinct o.nro_operacion, d.cod_rub_economico, d.fecha
  FROM (select nro_operacion, max(fecha) fecha
       from SB_CRC_OPERACIONES_DET
       group by nro_operacion) o
       join SB_CRC_OPERACIONES_DET d on o.nro_operacion = d.nro_operacion and o.fecha = d.fecha
            and d.nro_registro = (select max(x.nro_registro) 
                                  from SB_CRC_OPERACIONES_DET x
                                  where x.nro_operacion= o.nro_operacion
                                  and x.fecha = o.fecha);
  -- recupera creditos vigentes y vencidos con capital y/o devengado no cobrado
  insert into SB_DAT_FIN_CREDITOS_TMP
   SELECT c.cod_persona, c.nro_cuenta, 
    g.cod_moneda,
    nvl(s.sal_capital,0) sal_capital,
    nvl(s.sal_int_dev_no_cobrado,0) dev_no_cobrado,
    o.cod_rub_economico,
    s.rub_con_capital,
    substr(s.rub_con_capital,1,2),
    g.cod_modulo,
    g.cod_modalidad,
    m.des_grupo_mis
  FROM SB_CRC_SALDOS_DET s 
       join GE_CTA_CLIENTES c on substr(s.nro_operacion,1,10) = c.nro_cuenta and c.relacion = 'P'
       left join SB_DAT_FIN_RUB_ECONOMICOS_TMP o on o.nro_operacion = s.nro_operacion       
       left join GE_CUENTAS g on c.nro_cuenta = g.nro_cuenta
       left join (select distinct nro_cuenta, des_grupo_mis from SB_DAT_FIN_INV_RENTABLE_TMP
           where des_subactividad_mis IN ('AUTOMOVILES','TARJETAS DE CREDITO',
           'HIPOTECARIO - VIVIENDA','CONSUMO')) m on m.nro_cuenta = g.nro_cuenta      
  WHERE substr(s.rub_con_capital,1,2) IN (13,14,16)
    AND s.fecha = vg_fec_actual
    AND (nvl(s.sal_capital,0) <> 0 or nvl(s.sal_int_dev_no_cobrado,0) <> 0);
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
 	prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_CREDITOS_TMP;
-- Inserta Codigos de SB y rubros economicos implicados existentes en ITGF
procedure LP_INS_CODIGOS_TMP is
begin
   vg_lugar      := 'LP_INS_CODIGOS';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   insert into SB_DAT_FIN_RUB_INFORME_TMP( cod_informe, cod_rub_economico)
   select pa.cod_informe,  re.cod_rub_economico
   from SB_DAT_FIN_PARAMETROS pa,
        PR_RUB_ECONOMICOS re  
   where 
      -- filtro por sector economico
     (
      -- busca por substr del cod_bco_central
      (substr(re.cod_bco_central,0,pa.niv_actividad) in	(SELECT trim(regexp_substr(pa.cod_actividad||',', '[^,]+', 1, LEVEL))
                                                 FROM dual
                                                 CONNECT BY regexp_substr(pa.cod_actividad||',' , '[^,]+', 1, LEVEL) IS NOT NULL)
       and pa.niv_actividad IN (2,3,4))
       -- busca por cod_rub_eco_padre
       or ((re.cod_rub_eco_padre in	(SELECT trim(regexp_substr(pa.cod_actividad||',', '[^,]+', 1, LEVEL))
                                     FROM dual
                                     CONNECT BY regexp_substr(pa.cod_actividad||',' , '[^,]+', 1, LEVEL) IS NOT NULL)
       and pa.niv_actividad IN (1)))
     );
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
 	 prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_CODIGOS_TMP;
-- Inserta personas con creditos vigentes o vencidos y datos adicionales
procedure LP_INS_PERSONAS_TMP is
   v_sb_min_exigido pr_parametros.cap_min_exigido%type;
   v_sb_por_entidad pr_parametros.por_cap_min_exigido%type;
   v_sb_por_sistema pr_parametros.por_cap_min_exi_sistema%type;
   v_sb_min_entidad pr_parametros.cap_min_exigido%type;
   v_sb_min_sistema pr_parametros.cap_min_exigido%type;
begin
   vg_lugar      := 'LP_INS_PERSONAS';
   vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
   SELECT cap_min_exigido,
          por_cap_min_exigido,
          por_cap_min_exi_sistema
   INTO v_sb_min_exigido,
        v_sb_por_entidad,
        v_sb_por_sistema
   FROM PR_PARAMETROS;
   
   v_sb_min_entidad := v_sb_min_exigido * v_sb_por_entidad / 100;
   v_sb_min_sistema := v_sb_min_exigido * v_sb_por_sistema / 100;
   
   INSERT into SB_DAT_FIN_PERSONAS_TMP(cod_persona, cod_mon_predominante, tip_credito, sub_segmentacion, tip_persona, cod_gru_economico)
   SELECT p.cod_persona,
        a.val_parametro,
        --Grandes Deudores: supera el 2% en la entidad, o el 4% en el sistema financiero
        case when total_bbva > v_sb_min_entidad then
             'G'
        when total_sistema > v_sb_min_sistema then
             'G'
        else
           null
        end tip_credito,
        --Pymes
        case when m.cod_persona = p.cod_persona and s.cod_persona = p.cod_persona then
             'P'
        else
             null
        end sub_segmentacion,
        c.tipo tip_persona,
        decode( g.cod_persona, r.cod_persona, r.cod_gru_economico, g.cod_gru_economico) cod_gru_economico
   FROM (select distinct cod_persona FROM SB_DAT_FIN_CREDITOS_TMP) p
     left join (select o.cod_persona,
                 e.cod_gru_economico,
                 sum(nvl(o.tot_deu_real,0)) + sum(nvl(o.tot_deu_contingente,0)) TOTAL_BBVA,
                 nvl(e.tot_deu_sistema,0) + nvl(e.tot_deu_con_sistema,0) + sum(nvl(o.tot_deu_real,0)) + sum(nvl(o.tot_deu_contingente,0)) total_sistema
                from GE_CLA_OPERACIONES o, GE_CLIENTES e 
                     where o.cod_persona=e.cod_persona
                group by o.cod_persona, e.cod_gru_economico, nvl(e.tot_deu_sistema,0) + nvl(e.tot_deu_con_sistema,0)) g on g.cod_persona = p.cod_persona
     left join BA_PER_DAT_ADICIONALES a on p.cod_persona = a.cod_persona and a.parametro = 'MON_PREDOMINANTE'
     left join SB_DAT_FIN_BAN_TOTAL_TMP S on S.cod_persona = P.cod_persona and S.segmento IN ('03_SMALL','04_MICRO')
     left join (select distinct t.cod_persona from SB_DAT_FIN_INV_RENTABLE_TMP t 
                where DES_GRUPO_MIS = 'MAYORISTA') M on M.cod_persona = P.cod_persona
     left join BA_PERSONAS c on c.cod_persona = p.cod_persona
     left join SB_DAT_FIN_PER_GRUPOS_TMP r on r.cod_persona = g.cod_persona;
   vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
   prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_PERSONAS_TMP;
-- Inserta registros de cantidad de deudores del Informe Financiero
procedure LP_INS_INF_DEUDORES is
begin
  vg_lugar      := 'LP_INS_INF_DEUDORES';
  vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr,
       SB_DAT_FIN_PERSONAS_TMP pe,
       SB_DAT_FIN_PARAMETROS pa,
       SB_DAT_FIN_RUB_INFORME_TMP co
  where pr.cod_persona = pe.cod_persona
    and pe.cod_mon_predominante = 'L'
    and pr.cod_rub_economico = co.cod_rub_economico
    and co.cod_informe = pa.cod_informe
    and decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and pa.tipo = 'deudores'
  group by pa.cod_informe;
  -- 20 Otros
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PERSONAS_TMP pe on pr.cod_persona = pe.cod_persona and pe.cod_mon_predominante = 'L'
       join SB_DAT_FIN_PARAMETROS pa on pa.tipo = 'deudores' and pa.cod_informe = 20
       left join SB_DAT_FIN_RUB_INFORME_TMP co on pr.cod_rub_economico = co.cod_rub_economico 
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and co.cod_rub_economico is null
  group by pa.cod_informe;
  -- 21 Personas Fisicas
  -- 22 Personas Juridicas
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.tipo = 'deudores' and pa.cod_informe IN (21,22)
       join SB_DAT_FIN_PERSONAS_TMP pe on pr.cod_persona = pe.cod_persona and pe.cod_mon_predominante = 'L' and pe.tip_persona = pa.filtro   
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
  group by pa.cod_informe;
  -- 23 Personas Vinculados a la Entidad
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.tipo = 'deudores' and pa.cod_informe = 23
       join SB_DAT_FIN_PERSONAS_TMP cl on cl.cod_persona = pr.cod_persona and cl.cod_gru_economico = vg_gru_eco_entidad
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    or nvl(pa.cod_tip_moneda,'X') = 'X'
  group by pa.cod_informe;
  -- 24 Grandes Deudores
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.tipo = 'deudores' and pa.cod_informe IN (24)
       join SB_DAT_FIN_PERSONAS_TMP pe on pe.cod_persona = pr.cod_persona and pe.tip_credito = pa.filtro
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    or nvl(pa.cod_tip_moneda,'X') = 'X'
  group by pa.cod_informe;
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
  -- 25 Microcreditos
  -- 26 Pymes
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, count(distinct pr.cod_persona) 
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.tipo = 'deudores' and pa.cod_informe IN (25,26)
       join SB_DAT_FIN_PERSONAS_TMP pe on pe.cod_persona = pr.cod_persona and pe.sub_segmentacion = pa.filtro
  where
    (decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    or nvl(pa.cod_tip_moneda,'X') = 'X')
    and pr.des_gru_mis is null    
  group by pa.cod_informe;
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_INF_DEUDORES;
-- Inserta registros de saldos del Informe Financiero por codigo
procedure LP_INS_INF_CREDITOS is
begin
  vg_lugar      := 'LP_INS_INF_CREDITOS';
  vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');  
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0) + nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr,
       SB_DAT_FIN_PARAMETROS pa,
       SB_DAT_FIN_RUB_INFORME_TMP co,
       SB_DAT_FIN_PERSONAS_TMP pe
  where pr.cod_rub_economico = co.cod_rub_economico
    and pr.cod_persona = pe.cod_persona 
    and pe.cod_mon_predominante = 'L'
    and co.cod_informe = pa.cod_informe
    and decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos'))
  group by pa.cod_informe;
  -- Grandes Deudores 
  -- Vigentes 44 ME, 48 MN
  -- Vencidos 68 ME, 72 MN
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0)+nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.cod_informe IN (44,48,68,72)
       join SB_DAT_FIN_PERSONAS_TMP pe on pe.cod_persona = pr.cod_persona and pe.tip_credito = pa.filtro
  where
    (decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
      or nvl(pa.cod_tip_moneda,'X') = 'X')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos')) 
  group by pa.cod_informe;
  -- Pymes
  -- vigentes 46 ME, 50 MN 
  -- vencidos 70 ME, 74 MN
  -- Microcreditos 
  -- Vigentes 45 ME, 49 MN
  -- Vencidos 69 ME, 73 MN
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0)+nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.cod_informe IN (46,50,70,74,45,49,69,73)
       join SB_DAT_FIN_PERSONAS_TMP pe on pe.cod_persona = pr.cod_persona and pe.sub_segmentacion = pa.filtro
  where
    (decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
      or nvl(pa.cod_tip_moneda,'X') = 'X')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos'))
    and pr.des_gru_mis is null
  group by pa.cod_informe;  
  -- Otros 40 Vigentes, 64 Vencidos
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0)+nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.cod_informe IN (40,64)
       join SB_DAT_FIN_PERSONAS_TMP pe on pr.cod_persona = pe.cod_persona and pe.cod_mon_predominante = 'L'
       left join SB_DAT_FIN_RUB_INFORME_TMP co on pr.cod_rub_economico = co.cod_rub_economico 
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos'))
    and co.cod_rub_economico is null
  group by pa.cod_informe;
  -- Personas Fisicas: 41 Vigentes, 65 Vencidas
  -- Personas Juridicas: 42 Vigentes, 66 Vencidas
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0)+nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr       
       join SB_DAT_FIN_PERSONAS_TMP pe on pr.cod_persona = pe.cod_persona and pe.cod_mon_predominante = 'L'
       join SB_DAT_FIN_PARAMETROS pa on pa.cod_informe IN (41,42,65,66) and pe.tip_persona = pa.filtro
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos'))
  group by pa.cod_informe;
  -- Personas Vinculados a la Entidad 
  -- vigentes 43 ME, 47 MN 
  -- vencidos 67 ME, 71 MN
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(sum(nvl(pr.sal_capital,0)+nvl(pr.dev_no_cobrado,0)),0)
  from SB_DAT_FIN_CREDITOS_TMP pr
       join SB_DAT_FIN_PARAMETROS pa on pa.cod_informe IN (43,47,67,71)
       join SB_DAT_FIN_PERSONAS_TMP cl on cl.cod_persona = pr.cod_persona and cl.cod_gru_economico = vg_gru_eco_entidad
  where
    decode(pa.cod_tip_moneda,'MN','GS','ME') = decode(pr.cod_moneda,'GS',pr.cod_moneda,'ME')
    and ((pr.estado_rub IN ('13','14') and pa.tipo='vigentes')
      or (pr.estado_rub IN ('16') and pa.tipo='vencidos'))
  group by pa.cod_informe;
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_INF_CREDITOS;
--Inserta registros de saldos contables del Informe Financiero
procedure LP_INS_INF_RATIOS is
begin 
  vg_lugar      := 'LP_INS_INF_RATIOS';
  vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');   
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, pa.cod_informe, round(nvl(ra.monto,0),0)
  from SB_DAT_FIN_PARAMETROS pa
       join SB_DAT_FIN_RATIOS_TMP ra on pa.cod_informe = ra.cod_informe
  where pa.tipo = 'contables';
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_INF_RATIOS;
--Inserta registros de codigos sin saldos a la fecha con valor 0
procedure LP_INS_INF_NOEXISTENTES is
begin
  vg_lugar      := 'LP_INS_INF_NOEXISTENTES';
  vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');   
  insert into SB_DAT_FINANCIEROS(fecha, cod_informe, valor)
  select vg_fec_actual, p.cod_informe, 0
  from SB_DAT_FIN_PARAMETROS p
       left join SB_DAT_FINANCIEROS i on p.cod_informe = i.cod_informe and i.fecha = vg_fec_actual
  where i.cod_informe is null;
  vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos(vg_cod_programa, vg_lugar, trunc(sysdate), vg_hor_inicio, vg_hor_fin);
end LP_INS_INF_NOEXISTENTES;
begin
  vg_cod_programa := 'PRS_GEN_DAT_FINANCIEROS';
  vg_gru_eco_entidad := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD');
  select max(fecha) into vg_fec_actual from sb_crc_saldos_det;
  -- limpia tablas temporales
  lp_pre_tablas;
  -- inserta datos actuales de creditos
  lp_ins_creditos_tmp;
  -- inserta codigos del informe
  lp_ins_codigos_tmp; 
  -- inserta datos de personas de personas
  lp_ins_personas_tmp;
  -- inserta registros de cantidad de deudores
  lp_ins_inf_deudores;
  -- inserta registros de saldos de creditos
  lp_ins_inf_creditos;
  -- inserta resumen de ratios contabilidad
  lp_ins_inf_ratios;
  -- inserta cero en codigos con saldo 0
  lp_ins_inf_noexistentes;
end PRS_GEN_DAT_FINANCIEROS;
/

