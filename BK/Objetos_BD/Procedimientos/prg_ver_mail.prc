CREATE OR REPLACE PROCEDURE IT.PRG_VER_MAIL IS

  V_DIR_CORREO_DE    VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  V_DIR_CORREO_PARA  VARCHAR2(300) := fug_obt_pardinamico('CAM_MAR_DIR_EP');--'ep.py@bbva.com';
  V_DIR_CORREO_PARA2 VARCHAR2(300) := fug_obt_pardinamico('CAM_MAR_DIR_GUA_CIE');--'guardia.cierre.dyd.py.group@bbva.com';
  V_DIR_CORREO_CC    VARCHAR2(300) := fug_obt_pardinamico('CAM_MAR_DIR_SOP');--'soporte.incidencias.dyd.py.group@bbva.com';
  V_FEC_ACTUAL       DATE := TRUNC(pae_cnf.FU_OBT_FEC_ACTUAL(1));
  V_FEC_ANTERIOR     DATE := pag_cal.FU_OBT_FEC_ANTERIOR(1);  
  V_MARCA            NUMBER := 0;
  v_BAN              Number:=0;
  v_ult_embarque     cx_embarques.nro_embarque%type;
  v_lon_texto number(4);
  v_nro_cuenta varchar2(4000);
  v_exi_transaccion varchar2(1);
  v_cod_tip_asiento ge_transacciones.cod_tip_asiento%type;  
  v_can_registros number(4);
  v_envios varchar2(4000);

  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10); 
  V_FIN      LONG := ' </tbody>
                         </table> <BR> Favor gestionar las incidencias criticas antes de iniciar el cierre operativo<BR><BR>
                          <table width="400" border="0" cellpadding="0" cellspacing="0">
                         <tbody> '||chr(10)||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',V_DIR_CORREO_DE);
  --
  V_DETALLE  LONG := '';
  V_CABECERA LONG := '<html>
                  <body>
                  <BR>
                         Buenas tardes, remitimos el listado con los posibles errores durante el cierre diario, verificar datos a fin de evitar errores.
                  <br><br>
                  </p>
                  <table  width: 50%;
                          cellspacing="0"
                          cellpadding="5"
                          border="4">
                  <tr>
                    <td width="40%" bgcolor="B0C4DE"> <b>ERRORES</b></td>
                    <td width="50%" bgcolor="B0C4DE"> <b>DETALLE</b></td>
                    <td width="10%" bgcolor="B0C4DE"> <b>PRIORIDAD</b></td>
                  </tr>';

  -----------Movimientos en guaranies con decimales
  CURSOR C_VER1 IS 
    select 'CTA: '||a.nro_cuenta cant
      from ge_movimientos a
     where A.COD_MONEDA = 'GS'
       AND round(A.MONTO) <> A.MONTO; 

  -----------Clientes en ge_cuentas pero que no existe en ge_cta_clientes
  CURSOR C_VER2 IS 
    select m.cod_modulo, m.cod_modalidad, m.nro_cuenta
      from GE_CUENTAS m
     where not exists
         (select 1
                  from ge_cta_clientes e
                 where e.nro_cuenta = m.nro_cuenta)
           and m.nro_cuenta not in
               ('3110037653', '3110037661', '3110037670', '3110037688', '3110037696',
                '3110037700', '3110037718', '3110037726', '3110037734', '3110037742',
                 3110036053, 3110036061, 3110036070, 3110036088, 3110036096, 3110036100, 
                 3110036118, 3110036126, 3110036134, 3110036142, 3110036150, 3110036169, 
                 3110036177, 3110036045);

  -----------Clientes en ge_cta_clientes pero que no existe en ge_cuentas
  CURSOR C_VER3 IS 
    select a.cod_modulo, a.cod_modalidad, a.nro_cuenta 
      from GE_CTA_CLIENTES A
     where not exists (select 1
                         from GE_CUENTAS N
                        where A.NRO_CUENTA = N.NRO_CUENTA);

  /** Se comenta esta porcion de codigo para que no envie correode los movimientos de la oficina 32 - Issue 1915
  CURSOR C_VER4 IS -------------movimientos con oficina 32
    select *
      from (select count(1) as cant
              from (select ss.nro_cuenta
                      from ge_movimientos ss
                     where ss.cod_oficina = '32'
                    union all
                    select cj.nro_cuenta
                      from cj_movimientos cj
                     where cj.cod_oficina = '32') xx) x
     where x.cant <> 0;
   */
  -----------Movimientos de cuentas que no existen en ge_cta_clientes
  CURSOR C_VER5 IS 
    select distinct m.cod_modulo||'-'||m.cod_modalidad||'-'||m.nro_cuenta as nro_cuenta
      from ge_movimientos m
     where m.nro_cuenta is not null
       and not exists (select 1
                         from ge_cta_clientes e
                        where e.nro_cuenta = m.nro_cuenta
                        --and e.cod_oficina = m.cod_oficina
                          and e.cod_modalidad = m.cod_modalidad
                          and e.relacion = 'P');

  -----------Cuenta de clientes que no esta asociado a un cliente
  CURSOR C_VER6 IS 
    select tt.cod_modulo||'-'||tt.cod_modalidad||'-'||tt.nro_cuenta as nro_cuenta
      from ge_cta_clientes tt
     where tt.relacion = 'P'
       and not exists
           (select 1
              from ge_clientes ss
                     where ss.cod_persona = tt.cod_persona);

  -----------Estado de cajas
  CURSOR C_VER7 IS
     select a.nro_caja ||' - ' || a.descripcion ||' - ' || d.descripcion ||' - ' || c.dir_correo AS CAJA
          from cj_cajas a, cj_controles b, ba_usuarios c, ba_oficinas d
         where a.nro_caja = b.nro_caja
           and b.estado <> 2
           and a.cod_usuario = c.cod_usuario
           and d.cod_oficina = a.cod_oficina
           and b.FECHA = V_FEC_ACTUAL
    group by a.nro_caja, a.descripcion, d.descripcion, c.dir_correo;

  -----------Movimientos pendientes   
  CURSOR C_VER8 IS
    select decode(a.estado, 'J', 'Pendiente de pasar por caja') Estado_Caja,
           a.cod_oficina Oficna_Cuenta,
           a.nro_cuenta,
           a.cod_persona as PERSONA
      from ge_movimientos a, ba_usuarios b
     where a.estado in ('J')
       and a.reversado = 'N'
       and b.cod_usuario = a.cod_usuario;

  -----------Movimientos con oficina y nulo
  CURSOR C_VER9 IS 
    select fecha, hora, cod_usuario, nro_secuencia, nro_cuenta
      from ge_movimientos t
     where t.cod_oficina is null;

  -----------Control de Operaciones Comex Pendientes
  CURSOR C_VER10 IS
    select m.fecha,
           m.hora,
           m.cod_usuario,
           m.nro_secuencia,
           m.fec_valor,
           m.monto,
           m.cod_moneda,
           m.cod_oficina,
           m.concepto
      from ge_movimientos m
     where reversado = 'N'
       and fecha = trunc(sysdate)
       and nro_secuencia = 1
       and exists (Select 1
              from ge_aut_pedidos p
             where respuesta = 'P'
               and estado = 'S'
               and p.hora = m.hora
               and p.cod_usuario = m.cod_usuario)
       and m.nro_documento =
           (select s.nro_solicitud
              from pr_solicitudes s
             where s.estado not in ('A', 'L')
               and fux_obt_cci_prestamo(m.nro_documento) is not null
               and s.nro_solicitud = m.nro_documento);

  -----------Transferencias en con corres
  CURSOR C_VER11 IS
    select t.nro_referencia,
           substr('//' || nro_ref_externa || '//' || nom_beneficiario,
                  1,
                  100) concepto
      from lc_transferencias t
     where t.fec_cam_estado = fue_obt_fec_calendar(7)
       and t.cod_modalidad = 75
       and t.estado in ('AN', 'DE')
       and not exists (select c.nro_cuenta, c.cod_oficina
              from cc_cta_bancarias c
             where c.cod_banco = t.cod_bco_corresponsal
               and c.cod_modalidad = 45
               and c.estado = 'N'
               and c.cod_moneda = t.cod_moneda);


  /* -- DYDMR-5242 NAF Oct/2016
  -- Se comenta control de fechas de Extracto Aduanas,
  -- las fechas ya se ajustan automaticamente en el env韔
  cursor c_ver12 is --------------------error en aduana
       select ww.cant from ( select count(1) cant from (
        SELECT TO_CHAR(fecha, 'dd/mm/yyyy') as fecha
          FROM GE_TRANSACCIONES, ge_movimientos
         WHERE ge_movimientos.NRO_CUENTA = 1101700874
           AND ge_movimientos.FECHA = pae_cnf.FU_OBT_FEC_ACTUAL(1)
           AND (ge_movimientos.REVERSADO = 'N' or
               (ge_movimientos.REVERSADO = 'S' and
               FEC_VALOR <= pae_cnf.FU_OBT_FEC_ACTUAL(1)))
           AND ge_movimientos.ESTADO = 'N'
           AND ge_movimientos.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
           AND ge_movimientos.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
           AND ge_movimientos.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
           AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
           AND GE_TRANSACCIONES.TIPO IN ('C', 'D')
           AND cod_tra_padre not in (219, 220, 222, 226) -- se genera en el query
           AND (NVL(GE_TRANSACCIONES.AFECTA, 'XX') = 'B' AND
               ge_movimientos.COD_CAUSA IN
               (select cod_causa
                   from ge_par_causales
                  where parametro = 'COD_CAU_BLO_EXT'
                    and val_parametro = 'S') OR
               NVL(GE_TRANSACCIONES.AFECTA, 'XX') != 'B')
        UNION ALL
        SELECT to_char(to_date(SUBSTR(REQUEST, 11, 8), 'yyyy/mm/dd'), 'dd/mm/yyyy') as fecha
          from ge_dna_log x, ge_movimientos a
         where status in ('S')
           AND codigoerror = 0
           and x.tipo = decode(a.cod_tra_padre,226,'TLE',222,'TCA',219,'TDA',220,'TID')
           and tipooperacion in ('E', 'T', 'C')
           and a.nro_cuenta = 1101700874
           and a.fecha = pae_cnf.FU_OBT_FEC_ACTUAL(1)
           and a.cod_tra_padre in (219, 220, 222, 226)
           and a.estado = 'N'
           and a.reversado = 'N'
           and x.monto = a.monto
           and x.iddepositobanco = nro_documento
           and trunc(x.fechainserccion) = trunc(a.fec_insercion)
           and x.usuario = a.cod_usuario ) xx
           where to_date(xx.fecha,'dd/mm/yyyy') <> pae_cnf.FU_OBT_FEC_ACTUAL(1)) ww
           where ww.cant <> 0;*/
           
  -----------Rubros con tipos de rubro incorrectos
  CURSOR C_VER13 IS 
    select *
      from (select count(1) as cant
              from ge_movimientos
             where cod_rubro is not null and tip_mov_rubro not in ('D','C') and tip_mov_rubro is not null) x
     where x.cant <> 0;

  -----------Error aduana de reverso
  CURSOR C_VER14 IS
    select * 
      from (select count(1) as cant 
              from ( SELECT  '' || '#' || -- idliquidacion
                             TO_CHAR(fecha,'YYYYMMDD')||REPLACE(hora,':','') || '#' || -- FechaTransaccion
                             (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta),
                                              'C',
                                              NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)) || '#' || -- MontoCredito
                             (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta),
                                              'D',
                                              NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)) || '#' || -- MontoDebito
                             '' || '#' || -- idTransBandna
                             '' || '#' || -- idTransBanco
                             ''  datos, -- Observacion
                             decode(REVERSADO,'S','REV',
                                    decode(cc_movimientos_his.cod_tra_padre,309,'TRAN',
                                    decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                                            ge_transacciones.tipo,
                                                            ge_transacciones.afecta),
                                                            'C','CRE','D','DEB'))) concepto,
                             decode(cc_movimientos_his.cod_tra_padre,309,
                             pag_dna.fu_obt_cta_destino(cc_movimientos_his.fecha,
                                                        cc_movimientos_his.cod_usuario,
                                                        cc_movimientos_his.hora,
                                                        cc_movimientos_his.cod_tra_padre,
                                                        cc_movimientos_his.cod_transaccion)) cuentaDestino,
                             CC_MOVIMIENTOS_HIS.fec_insercion fecha,
                             fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                              ge_transacciones.tipo,
                                              ge_transacciones.afecta) tipo,
                              CC_MOVIMIENTOS_HIS.monto monto,
                              reversado
                         FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
                     WHERE CC_MOVIMIENTOS_HIS.NRO_CUENTA = '1101700874'
                       AND CC_MOVIMIENTOS_HIS.FECHA = V_FEC_ACTUAL
                       AND (CC_MOVIMIENTOS_HIS.REVERSADO = 'N' or (CC_MOVIMIENTOS_HIS.REVERSADO='S' and FEC_VALOR <= V_FEC_ACTUAL))
                       AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
                       AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                       AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                       AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                       AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                       AND GE_TRANSACCIONES.TIPO IN ('C','D')
                       AND cod_tra_padre not in (219,220,222,226) -- se genera en el query
                       AND (NVL(GE_TRANSACCIONES.AFECTA,'XX') = 'B'
                           AND CC_MOVIMIENTOS_HIS.COD_CAUSA IN
                                 (select cod_causa
                                    from ge_par_causales
                                   where parametro = 'COD_CAU_BLO_EXT'
                                     and val_parametro = 'S' )
                           OR NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B' )
                 UNION ALL
                    SELECT  IDTICKET || '#' || -- idliquidacion
                            SUBSTR(REQUEST,11,14) || '#' || -- FechaTransaccion
                            x.MONTO || '#' || -- MontoCredito
                            '0' || '#' || -- MontoDebito
                            IDDEPOSITODNA || '#' || -- idTransBandna
                            IDDEPOSITO || '#' || -- idTransBanco
                            ''  datos, -- Observacion
                            DECODE(TIPO,'TLE','LIQ','TCA','LIQ',TIPO) concepto,
                            '' cuentaDestino,
                            a.fec_insercion fecha,
                            'C' tipo,
                            x.monto monto,
                            a.reversado
                    from  ge_dna_log x, cc_movimientos_his a
                    where status in ('S')
                    AND   codigoerror = 0
                    and   x.tipo = decode(a.cod_tra_padre,226,'TLE',222,'TCA',219,'TDA',220,'TID')
                    and   tipooperacion in ('E','T','C')
                    and   a.nro_cuenta = '1101700874'
                    and   a.fecha = V_FEC_ACTUAL
                    and   a.cod_tra_padre in (219,220,222,226)
                    and   a.estado = 'N'
                    and   a.reversado = 'N'
                    and   x.monto = a.monto
                    and   x.iddepositobanco = nro_documento
                    and   trunc(x.fechainserccion) = trunc(a.fec_insercion)
                    and   x.usuario = a.cod_usuario
                order by 2) z 
             where z.concepto  = 'REV') xx 
     where xx.cant <> 0;

  -----------Rubros con tipos de rubro incorrectos
  CURSOR C_VER15 IS
    select c.nro_cuenta
      from ah_cta_certificados c
     where c.estado = 'A'
       and trunc(c.fec_insercion) = trunc(sysdate)
       and c.cod_modalidad <> '36'; -- SC 11416 (DYDMR-1397): Se verifica en el cursor c_ver17
  
  -----------
  CURSOR C_VER16 IS
    select a.nro_cuenta, a.hora, a.cod_usuario, a.nro_documento2
      from ge_movimientos a
     where a.cod_modulo = 8
       and a.estado = 'P'
       and a.reversado = 'N'
       and a.cod_tra_padre IN (368, 384)
       and a.nro_secuencia = 1
       and a.monto <> 0
       and a.nro_documento3 is not null;

  -----------
  CURSOR C_VER17 IS
    select *
      from (select count(1) as cant
              from ah_cta_certificados c
             where c.estado = 'A'
               and trunc(c.fec_insercion) = trunc(sysdate)
               and c.cod_modalidad = '36') x
     where x.cant <> 0;

  -----------
  CURSOR C_VER18 IS
    select a.nro_documento, a.hora, a.cod_usuario, a.cod_modulo, a.cod_modalidad,a.cod_transaccion
      from gv_movimientos a, ge_gru_transacciones_det t
     where a.FECHA = V_FEC_ANTERIOR
       and t.cod_gru_transaccion = 80  -- grupo de transaccion de Cobro de Operacion Vencida con Cheque
       and a.COD_MODULO = t.cod_modulo
       and a.COD_MODALIDAD = t.cod_modalidad
       and a.COD_TRANSACCION = t.cod_transaccion
       and a.reversado = 'N'
       and a.estado = 'N'
       and a.monto <> 0;

  -- Control de movimientos cod. rubro contable inconrrecto.
  -- DYDMR-1738 - Verificaci贸n Inicial del cierre - PRA_VER_INI_CIERRE - SC 14901 - EGC/13/04/2015.
  CURSOR C_VER19 IS
    select m.fecha,
           m.hora,
           m.cod_usuario,
           m.nro_secuencia,
           m.cod_rubro,
           m.cod_moneda
      from ge_movimientos m
     where m.cod_rubro is not null
       and ((not exists (select 0
              from cb_rubros b
             where b.cod_rubro = m.cod_rubro
               and b.cod_moneda = m.cod_moneda))  OR
           (m.cod_rubro like '11120%'
       and m.cod_modalidad in (31,41)
       and m.nro_cuenta is not null ));   --DYDMR-5614 12/2016

  --Control de Cheques Custodia remitidos con tip_dato nulo y monto con decilames. 30/04/2015-EGC
  --DYDMR-1807-ITGF- Nuevos Controles para VERIFICACION PREVIA - Errores Cierre 23/04/2015 SC 15568
  CURSOR C_VER20 IS
    select c.fecha,
           c.cod_oficina,
           c.nro_cuenta,
           c.nro_cheque,
           c.monto,
           c.tip_dato
      from cc_che_remitidos c
     where c.tip_dato is null
       and c.fecha between PAG_CAL.FU_OBT_FEC_ANTERIOR(9) and PAG_CAL.FU_OBT_FEC_ACTUAL(9)
       and c.monto <> round(c.monto);

  --Control de AH_CTA_VISTAS donde Fecha de ultima capitalizaci贸n no puede ser menor a la de apertura.
  --DYDMR-1807-ITGF- Nuevos Controles para VERIFICACION PREVIA - Errores Cierre 23/04/2015 SC 15568
  CURSOR C_VER21 IS
    select t.nro_cuenta
      from ah_cta_vistas t
     where t.fec_apertura > t.fec_ult_capitalizacion;
  
  ---Verificaci髇 previa para prestamos duplicados en ATM / WEB
  ---DYDMR-4557 - Incidencia SAU - ITGF - Pr閟tamo por ATM Duplicado   
  CURSOR C_VER22 IS   
    select count(1), a.cod_persona, a.monto, a.fec_inicio, a.cod_modalidad, a.cod_moneda
      from pr_solicitudes a
     where a.cod_canal in (28,29)
       and a.fec_inicio = pag_cal.FU_OBT_FEC_ACTUAL(6)
     group by a.cod_persona, a.monto, a.fec_inicio, a.cod_modalidad, a.cod_moneda
    having count(1) > 1;
     
  ---Verificaci髇 previa para prestamos no desembolsados en ATM / WEB
  ---DYDMR-4970 - Incidencia SAU - ITGF - Pr閟tamo Pre-Aprobado Via ATM y No desembolsado    
  CURSOR C_VER23 IS   
    select a.nro_solicitud, a.cod_persona 
      from pr_solicitudes a
     where a.cod_canal in (28, 29)
       and a.estado = 'L';
  
  ----PCCDEEVO-1017
  ----Verificacion previa para Disponibilidad de Claves Token 
  CURSOR C_VER24 IS        
    select count(1) as can_disponible, a.tipo,
           decode(a.tipo, 'V', 'VIRTUAL', 'F', 'FISICO') as tipo_desc,
           decode(a.tipo, 'V', 'CAN_MIN_CLA_TOK_VIRTUAL', 'F', 'CAN_MIN_CLA_TOK_FISICO') as parametro,
           decode(a.tipo, 'V', nvl(fug_obt_pardinamico('CAN_MIN_CLA_TOK_VIRTUAL'), 0), 
                          'F', nvl(fug_obt_pardinamico('CAN_MIN_CLA_TOK_FISICO'), 0)) as val_parametro
      from bw_otp_seriales a
     where a.estado = 'D'
     group by a.tipo;
    
   ----PCCDEEVO-1017
   ----Verificacion de circuitos en ejecuci髇 
   CURSOR C_VER25 IS        
     select t.cod_tip_circuito,
            t.tip_tiempo,
            t.tie_estimado,
            t.cod_tip_tarea,
            c.cod_obj_base,
            c.referencia,
            ci.cod_circuito,
            ci.fec_insercion,
            ci.cod_tar_actual,
            ci.referencia ref_relacion,
            ci.cod_persona,
            ct.usu_insercion, fue_obt_nom_usuario(ct.usu_insercion) as nom_usuario
       from wf_tip_cir_tareas t,
            wf_tip_circuitos  c,
            wf_circuitos      ci,
            wf_cir_tareas     ct
      where ci.estado = 'E' --Estado en ejecuci髇                         
        and ci.cod_circuito = ct.cod_circuito
        and ci.cod_tar_actual = ct.cod_tarea
        and ci.cod_tip_circuito = ct.cod_tip_circuito
        and ct.cod_tip_circuito = t.cod_tip_circuito
        and ct.cod_tip_tarea = t.cod_tip_tarea
        and t.act_automatica = 'S'
        and ct.cod_tip_circuito in (43, 44)
        and t.cod_tip_circuito = c.cod_tip_circuito;
        
  ----BSEVOCORE-415
  ----Pagos pendientes de TC Via Web Service 
  CURSOR C_VER26 IS
    select count(1)as Cant, 
      decode(w.estado, 'P','P-Pendiente','R','R-Rechazado')Estado, 
      w.fecha
     from ge_par_web_servicios w
     where w.estado not in ('E','X')
       and w.fecha = trunc(sysdate)
    group by w.estado, w.fecha
    having count(1) > 100;
     
BEGIN

------------------------------------------------------------------------------------------------------------------
------Prioridad de Alerta Alta ------ Color Rojo: 
------------------------------------------------------------------------------------------------------------------
  FOR REC IN c_ver14 LOOP
     V_MARCA   := 1;
     v_ban:=14;
     V_DETALLE := V_DETALLE ||'<tr>
                   <td bgcolor="FFFFFF">Error de boleta banco nulo en el extracto de aduanas (ver movimientos reversados)</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.CANT || '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';

    EXIT WHEN c_ver14%NOTFOUND;
  END LOOP;

  FOR REC IN c_ver13 LOOP
    V_MARCA   := 1;
    v_ban:=13;
    V_DETALLE := V_DETALLE ||'<tr>
                   <td bgcolor="FFFFFF">Existen movimientos con rubros con tipos de rubro incorrectos</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.CANT || '</td>
                    <td  bgcolor="DF0101">ALTA</td>
                  </tr> ';
    EXIT WHEN c_ver13%NOTFOUND;
  END LOOP;

  FOR REC IN c_ver11 LOOP
    V_MARCA   := 1;
    v_ban:=11;
    V_DETALLE := V_DETALLE || '<tr>
                   <td  bgcolor="FFFFFF">Existen transferencias con corresponsales incorrectos</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.nro_referencia || '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
    EXIT WHEN c_ver11%NOTFOUND;
  END LOOP;

  /* -- DYDMR-5242 NAF Oct/2016  
  FOR REC IN c_ver12 LOOP
    V_MARCA   := 1;
    v_ban:=12;
    V_DETALLE := V_DETALLE || '<tr>
                   <td  bgcolor="FFFFFF">Existen movimientos con fecha diferente al extracto de ADUANA</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.cant || '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
    EXIT WHEN c_ver12%NOTFOUND;
  END LOOP;*/

  FOR REC IN C_VER1 LOOP
    V_MARCA   := 1;
    v_ban:=1;
    V_DETALLE := V_DETALLE || '<tr>
                   <td bgcolor="FFFFFF">Existen movimientos en moneda local con decimales</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.cant || '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
    EXIT WHEN C_VER1%NOTFOUND;
  END LOOP;
  
  /** Se comenta esta porcion de codigo para que no informe moviemintos de la oficina 32 porque ya es una sucursal - Issue 1915
  FOR REC IN C_VER4 LOOP
    V_MARCA   := 1;
    V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen movimientos con oficina 32</td>
                  <td bgcolor="FFFFFF">' ||
                 REC.cant || '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
    EXIT WHEN C_VER4%NOTFOUND;
  END LOOP;*/

  FOR REC IN C_VER10 LOOP
    V_MARCA   := 1;
    v_ban:=10;
    V_DETALLE := V_DETALLE || '<tr>
                   <td bgcolor="FFFFFF">Existen operaciones de COMEX pendientes</td>
                    <td bgcolor="FFFFFF">' ||
                 REC.FECHA || '-' || rec.hora || '-' || rec.cod_usuario ||
                 '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
    EXIT WHEN C_VER10%NOTFOUND;
  END LOOP;

  FOR REC IN C_VER9 LOOP
    V_MARCA   := 1;
    v_ban:=9;
    V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen movimientos con oficina nula</td>
                  <td bgcolor="FFFFFF">' ||
                 REC.Nro_Cuenta || '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
    EXIT WHEN C_VER9%NOTFOUND;
  END LOOP;

  FOR REC IN C_VER7 LOOP
    V_MARCA   := 1;
    v_ban :=7;
    V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen cajas abiertas</td>
                  <td bgcolor="FFFFFF">' || REC.CAJA ||
                 '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
    EXIT WHEN C_VER7%NOTFOUND;
  END LOOP;
  --DE-2615 - Agregar control de cierre SIPAP en Verificaciones del cierre (PRA_VER_INI_CIERRE) - DYD-SDSL-3593
  --Verificacion Modulos SIPAP--
  SELECT NVL(COUNT(*),0)
    INTO V_CAN_REGISTROS
    FROM GE_SNP_HORARIOS A
   WHERE A.ESTADO <> 'C';
  IF NVL(V_CAN_REGISTROS,0) > 0 THEN
     V_MARCA   := 1;
     v_ban :=7;
     V_DETALLE := V_DETALLE ||
                  '<tr>
                  <td bgcolor="FFFFFF">Modulo de SIPAP Abierto</td>
                   <td bgcolor="FFFFFF">' ||
                  TO_CHAR(V_CAN_REGISTROS) ||' Modulos Abiertos '||
                  '</td>
                   <td bgcolor="DF0101">ALTA</td>
                 </tr> ';
  END IF;

  FOR REC IN C_VER8 LOOP
    V_MARCA   := 1;
    v_ban:=8;
    V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen movimientos pendientes</td>
                  <td bgcolor="FFFFFF">' ||
                 REC.Nro_Cuenta || ' / ' || REC.PERSONA || ' - ' ||
                 rec.Estado_Caja || '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
    EXIT WHEN C_VER8%NOTFOUND;
  END LOOP;

  v_lon_texto := 0;
  v_nro_cuenta := null;

  FOR REC IN C_VER2 LOOP
    V_MARCA   := 1;
    v_ban:=2;
    if v_nro_cuenta is null then
      v_nro_cuenta := rec.nro_cuenta;
    else
      v_nro_cuenta := v_nro_cuenta ||', '||rec.nro_cuenta;
    end if;
     v_lon_texto := length(v_nro_cuenta);
     if nvl(v_lon_texto,0) > 3500 then
        exit;
     end if;
    EXIT WHEN C_VER2%NOTFOUND;
  END LOOP;

  IF v_nro_cuenta is not null THEN

     V_DETALLE := V_DETALLE ||
                 '<tr>
                   <td bgcolor="FFFFFF">Existen registros de cuentas que no esta vinculado al cliente</td>
                    <td bgcolor="FFFFFF">' ||
                 'CTA: '||v_nro_cuenta || '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
  END IF;

  v_lon_texto := 0;
  v_nro_cuenta := null;
  FOR REC IN C_VER3 LOOP
    V_MARCA   := 1;
    v_ban:=3;
    if v_nro_cuenta is null then
      v_nro_cuenta := rec.nro_cuenta;
    else
      v_nro_cuenta := v_nro_cuenta ||', '||rec.nro_cuenta;
    end if;
     v_lon_texto := length(v_nro_cuenta);
     if nvl(v_lon_texto,0) > 3500 then
        exit;
     end if;

    EXIT WHEN C_VER3%NOTFOUND;
  END LOOP;

  IF v_nro_cuenta is not null THEN
     V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen cuentas sin el detalle de la cuenta (GE_CTA_CLIENTES)</td>
                  <td bgcolor="FFFFFF">' ||
                 'CTA: '||v_nro_cuenta || '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
  END IF;


  v_lon_texto := 0;
  v_nro_cuenta := null;
  FOR REC IN C_VER5 LOOP
    V_MARCA   := 1;
    v_ban:=5;
    if v_nro_cuenta is null then
      v_nro_cuenta := rec.nro_cuenta;
    else
      v_nro_cuenta := v_nro_cuenta ||', '||rec.nro_cuenta;
    end if;
     v_lon_texto := length(v_nro_cuenta);
     if nvl(v_lon_texto,0) > 3500 then
        exit;
     end if;

    EXIT WHEN C_VER5%NOTFOUND;
  END LOOP;

  IF v_nro_cuenta is not null THEN
     V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen movimientos de cuentas que no estan vinculados al cliente (GE_MOVIMIENTOS where not exists GE_CTA_CLIENTES)</td>
                  <td bgcolor="FFFFFF">' ||
                 v_nro_cuenta || '</td>
                  <td bgcolor="DF0101">ALTA</td>
                </tr> ';
  END IF;

  FOR rec IN c_ver18 LOOP
    v_marca := 1;
    v_ban := 18;

    begin
      select 'S', cod_tip_asiento
        into v_exi_transaccion, v_cod_tip_asiento
        from ge_transacciones
       where cod_modulo = rec.cod_modulo
         and cod_modalidad = rec.cod_modalidad
         and cod_transaccion = 906;
    exception
      when others then
        v_exi_transaccion := 'N' ;
    end;

    IF nvl(v_exi_transaccion, 'N') = 'S' and v_cod_tip_asiento is not null THEN
        v_detalle := v_detalle || '<tr>
                     <td bgcolor="FFFFFF"> Verificar la Transaccion '||to_char(rec.cod_modulo)||'-'||to_char(rec.cod_modalidad)||'-906.
                      Se generaran movimientos en el cierre que podria generar errores (proc.: PRA_GEN_ASIENTOS) - '||
                      'Fecha'||to_char(v_fec_anterior,'dd/mm/yyyy')||', Hora: ' || rec.hora || ', Usu: ' ||  rec.cod_usuario  ||' </td></td>
                     <td bgcolor="FFFFFF">' ||
                      'Nro doc. '||rec.nro_documento || '</td>
                     <td bgcolor="DF0101">ALTA</td>
                     </tr> ';
     ELSE
         v_detalle := v_detalle || '<tr>
                     <td bgcolor="FFFFFF"> La Transaccion '||to_char(rec.cod_modulo)||'-'||to_char(rec.cod_modalidad)||'-906 No Existe o no tiene asiento definido. Verificar ya que podria generar errores en el cierre (Proc: PRC_PRO_MOV_CAMARA, PRA_GEN_ASIENTOS). '||
                      'Fecha'||to_char(v_fec_anterior,'dd/mm/yyyy')||', Hora: ' || rec.hora || ', Usu: ' ||  rec.cod_usuario  ||' </td></td>
                     <td bgcolor="FFFFFF">' || 
                      'Nro doc. '||rec.nro_documento || '</td>
                     <td bgcolor="DF0101">ALTA</td>
                     </tr> ';
     END IF; 

  EXIT When c_ver18%NOTFOUND;

  END LOOP;
  
  -- Verificaci贸n Inicial del cierre - PRA_VER_INI_CIERRE - SC 14901 - DYDMR-1738 -.
   v_nro_cuenta := null;
  
  FOR REC IN C_VER19 LOOP
     V_MARCA   := 1;
     v_ban :=19;
     V_DETALLE := V_DETALLE ||
               '<tr>
               <td bgcolor="FFFFFF"> Existen movimientos con Rubro invalido. '||
                ' Fecha: ' ||to_char(rec.fecha,'dd/mm/yyyy') ||' Hora: ' || rec.hora ||' Usu: ' || rec.cod_usuario ||' Sec.: ' || rec.nro_secuencia ||' </td></td>
                <td bgcolor="FFFFFF">' ||
                'Rubro: '||rec.cod_rubro || '</td>
                <td bgcolor="DF0101">ALTA</td>
              </tr> ';
     EXIT WHEN C_VER19%NOTFOUND;
  END LOOP;
  
  --Control de Cheques Custodia remitidos con tip_dato nulo.
  --DYDMR-1807-ITGF- Nuevos Controles para VERIFICACION PREVIA - Errores Cierre 23/04/2015 SC 15568
  v_nro_cuenta := null;

  FOR REC IN C_VER20 LOOP
    V_MARCA   := 1;
    v_ban :=20;
    V_DETALLE := V_DETALLE ||
               '<tr>
               <td bgcolor="FFFFFF"> Existen cheques con montos decimales en cc_che_remitidos con tip_dato nulo. '||
                ' Fecha: ' ||to_char(rec.fecha,'dd/mm/yyyy')||' Ofic.: ' || rec.cod_oficina ||' Cuenta.: ' || rec.nro_cuenta ||' Nro. de Cheque: '
                || rec.nro_cheque||' Monto: ' || rec.monto||' Tip_dato: ' || rec.tip_dato||' </td></td>
                <td bgcolor="FFFFFF">' ||
                'Cheque Nro.: '||rec.nro_cheque || '</td>
                <td bgcolor="DF0101">ALTA</td>
              </tr> ';
    EXIT WHEN C_VER20%NOTFOUND;
  END LOOP;
  
  --Control de AH_CTA_VISTAS donde Fecha de ultima capitalizaci贸n no puede ser menor a la de apertura.
  --DYDMR-1807-ITGF- Nuevos Controles para VERIFICACION PREVIA - Errores Cierre 23/04/2015 SC 15568
  v_nro_cuenta := null;
  
  FOR REC IN c_ver21 LOOP
    V_MARCA   := 1;
    v_ban :=21;
    if v_nro_cuenta is null then
       v_nro_cuenta := REC.nro_cuenta;
     else
       v_nro_cuenta := v_nro_cuenta ||'<BR>'||REC.nro_cuenta;
     end if;
     
    EXIT WHEN C_VER21%NOTFOUND;
  END LOOP;
   
  IF v_nro_cuenta is not null THEN
   V_DETALLE := V_DETALLE ||
             '<tr>
             <td bgcolor="FFFFFF">AH_CTA_VISTAS existen cuentas con Fecha de 煤ltima capitalizaci贸n menor a fecha de apertura.</td></td>
             <td bgcolor="FFFFFF">' ||v_nro_cuenta || '</td>
             <td bgcolor="DF0101">ALTA</td>
            </tr> ';
  END IF;
  
  FOR REC IN c_ver25 LOOP
     V_MARCA   := 1;
     v_ban     :=25;
     V_DETALLE := V_DETALLE || '<tr>
                    <td bgcolor="FFFFFF">Existen Circuitos pendientes, verifique</td>
                    <td bgcolor="FFFFFF">' ||
                        'COD_TIP_CIRCUITO: '||rec.cod_tip_circuito||' - COD_PERSONA: '||rec.cod_persona||
                        ' - COD_CIRCUITO: '||rec.cod_circuito||' - COD_OBJ_BASE: '||rec.cod_obj_base||' - USUARIO: '||rec.nom_usuario||
                   '</td>
                    <td bgcolor="DF0101">ALTA</td>
                  </tr> ';
     EXIT WHEN c_ver25%NOTFOUND;
  END LOOP;
  
  v_envios := null;
  FOR REC IN C_VER26 LOOP
    V_MARCA   := 1;
    v_ban :=26; 
    v_envios := v_envios ||'Cant.:' ||REC.cant||', '||'Estado: '||rec.estado||', '||' Fecha: ' ||to_char(rec.fecha,'dd/mm/yyyy')||'<BR>';    
  EXIT WHEN C_VER26%NOTFOUND;
  END LOOP; 
 IF v_envios is not null THEN 
    V_DETALLE := V_DETALLE ||'<tr>
               <td bgcolor="FFFFFF"> Existen pagos de TDC Via Web Service pendientes de env韔. Verifique la tabla ge_par_web_servicios</td>
               <td bgcolor="FFFFFF">' ||
                v_envios||
               '</td>
                <td bgcolor="DF0101">ALTA</td>
              </tr> ';
  END IF;
  
------------------------------------------------------------------------------------------------------------------
------Prioridad de Alerta Baja ------ Color Amarillo: FFFF00
------------------------------------------------------------------------------------------------------------------

  FOR REC IN c_ver23 LOOP
     V_MARCA   := 1;
     V_DETALLE := V_DETALLE ||'<tr>
                   <td bgcolor="FFFFFF">Existen prestamos en estado pendiente de liquidaci髇, aprobados en el ATM / WEB, favor verifique e informe al gestor, Nro Solicitud: '
                   ||rec.nro_solicitud||',  </td>
                    <td bgcolor="FFFFFF">' ||'COD_PERSONA: '||
                 REC.cod_persona || '</td>
                    <td bgcolor="FFFF00">BAJA</td>
                  </tr> ';

     EXIT WHEN c_ver23%NOTFOUND;
  END LOOP;
  
  FOR REC IN c_ver22 LOOP
     V_MARCA   := 1;
     V_DETALLE := V_DETALLE ||'<tr>
                   <td bgcolor="FFFFFF">Existen prestamos duplicados, desembolsados en el ATM / WEB, favor verifique </td>
                    <td bgcolor="FFFFFF">' ||'COD_PERSONA: '||
                 REC.cod_persona || '</td>
                    <td bgcolor="FFFF00">BAJA</td>
                  </tr> ';

     EXIT WHEN c_ver22%NOTFOUND;
  END LOOP;

  v_lon_texto := 0;
  v_nro_cuenta := null;
  FOR REC IN C_VER6 LOOP
    V_MARCA   := 1;
    v_ban:=6;

    if v_nro_cuenta is null then
      v_nro_cuenta := rec.nro_cuenta;
    else
      v_nro_cuenta := v_nro_cuenta ||', '||rec.nro_cuenta;
    end if;

    v_lon_texto := length(v_nro_cuenta);

    if nvl(v_lon_texto,0) > 3500 then
       exit;
    end if;

    EXIT WHEN C_VER6%NOTFOUND;
  END LOOP;

  IF v_nro_cuenta is not null THEN
     V_DETALLE := V_DETALLE ||
                 '<tr>
                 <td bgcolor="FFFFFF">Existen registros de cuentas de clientes que no estan vinculados al cliente (GE_CTA_CLIENTES where not exists GE_CLIENTES)</td>
                  <td bgcolor="FFFFFF">' ||
                 v_nro_cuenta || '</td>
                  <td bgcolor="FFFF00">BAJA</td>
                 </tr> ';
  END IF;


  FOR REC IN c_ver15 LOOP
      V_MARCA   := 1;
      v_ban:=15;
      V_DETALLE := V_DETALLE || '<tr>
                     <td bgcolor="FFFFFF">Existen cuentas cda con estado abierto sin fondeo</td>
                        <td bgcolor="FFFFFF">' ||
                   REC.nro_cuenta || '</td>
                  <td bgcolor="FFFF00">BAJA</td>
                    </tr> ';
     EXIT WHEN c_ver15%NOTFOUND;
  END LOOP;

  FOR rec IN c_ver16 LOOP
     v_marca := 1;
     v_ban := 16;

     SELECT nvl(MAX(nro_embarque), 0)
       INTO v_ult_embarque
       FROM cx_cuotas
      WHERE monto <> nvl(saldo, 0) --algo pagado
        AND nro_cuenta = rec.nro_cuenta;

     IF rec.nro_documento2 < v_ult_embarque THEN
        v_detalle := v_detalle || '<tr>
                   <td bgcolor="FFFFFF">Existen EMBARQUES pendientes de confirmacion - Cta: '
                   || rec.nro_cuenta || ' Hora: ' || rec.hora || ' Cuo: ' || rec.nro_documento2 || ' Usu: ' ||  rec.cod_usuario  ||' </td>
                   <td bgcolor="FFFF00">BAJA</td>
                   </tr> ';
     END IF;
     
     EXIT When c_ver16%NOTFOUND;
  END LOOP;

  FOR rec in c_ver17 LOOP
    v_marca := 1;
    v_ban := 17;
    v_nro_cuenta := null;


    DECLARE
      CURSOR C_CTA_CDA_SBO IS
        SELECT c.nro_cuenta
          FROM ah_cta_certificados c
         WHERE c.estado = 'A'
           and trunc(c.fec_insercion) = trunc(sysdate)
           and c.cod_modalidad = '36'
           and rownum <= 10;

    BEGIN
      FOR c in c_cta_cda_sbo LOOP
        IF v_nro_cuenta is null THEN
          v_nro_cuenta := c.nro_cuenta;
        ELSE
          v_nro_cuenta := v_nro_cuenta ||', '||c.nro_cuenta;
        END IF;
      END LOOP;
    END;

    IF rec.cant > 10 THEN
       V_DETALLE := V_DETALLE ||
                     '<tr>
                     <td bgcolor="FFFFFF"> Existen '||rec.cant||' cuentas CDA de bonos subordinados con estado abierto sin fondeo, se detallan las primeras 10. </td>'||
                     'Cuentas: '||v_nro_cuenta || '</td>
                      <td bgcolor="FFFF00">BAJA</td>
                     </tr> ';
    ELSE
       V_DETALLE := V_DETALLE ||
                     '<tr>
                     <td bgcolor="FFFFFF"> Existen '||rec.cant||' cuentas CDA de bonos subordinados con estado abierto sin fondeo. </td>'||
                     'Cuentas: '||v_nro_cuenta || '</td>
                      <td bgcolor="FFFF00">BAJA</td>
                     </tr> ';
    END IF;
  END LOOP;
  
  FOR REC IN c_ver24 LOOP
     IF (rec.tipo = 'V' AND rec.can_disponible < rec.val_parametro) OR
        (rec.tipo = 'F' AND rec.can_disponible < rec.val_parametro) THEN
        V_MARCA   := 1;
        v_ban     :=24;
        V_DETALLE := V_DETALLE || '<tr>
                       <td bgcolor="FFFFFF">Se ha llegado al stock m韓imo parametrizado de Token</td>
                       <td bgcolor="FFFFFF">' ||
                           'TIPO: '||rec.tipo_desc ||' - CANTIDAD: '||rec.can_disponible || '. '||
                           'PARAMETRO: '||rec.parametro||': '||rec.val_parametro||
                      '</td>
                       <td bgcolor="FFFF00">BAJA</td>
                     </tr> ';
     END IF;
     EXIT WHEN c_ver24%NOTFOUND;
  END LOOP;
 
------------------------------------------------------------------------------------------------------------------
------SIN ERRORES------ Color VERDE: E0FFFF
------------------------------------------------------------------------------------------------------------------
  IF V_MARCA = 0 THEN
    V_CABECERA :=  '<html>
                  <body>
                  <table cellspacing="0"
                          cellpadding="5"
                          border="4">
                  <tr>
                    <td width="80%" bgcolor="1EC131"> <b> Buenas tardes, no existen errores que afecten al cierre diario!!!</b>      </td>
                  </tr>';                 
    V_DETALLE := '';
  END IF;

  PRG_SEND_MAIL(p_to        => V_DIR_CORREO_PARA,
                p_from      => V_DIR_CORREO_DE,
                p_subject   => 'VERIFICACION PREVIA AL CIERRE',
                p_text_msg  => '',
                p_html_msg  => v_membrete|| V_CABECERA || V_DETALLE || v_fin || v_pie ,
                p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                p_smtp_port => 25,
                pcc         => V_DIR_CORREO_CC);
  
  IF V_DIR_CORREO_PARA2 is not null THEN
     PRG_SEND_MAIL(p_to        => V_DIR_CORREO_PARA2,
                   p_from      => V_DIR_CORREO_DE,
                   p_subject   => 'VERIFICACION PREVIA AL CIERRE',
                   p_text_msg  => '',
                   p_html_msg  => v_membrete|| V_CABECERA || V_DETALLE || v_fin || v_pie ,
                   p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                   p_smtp_port => 25,
                   pcc         => '');
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'ERROR EN VERIFICACION PREVIA' ||v_ban|| SQLERRM);
END;
/

