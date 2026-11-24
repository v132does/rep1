create or replace procedure IT.PRT_TRA_SAL_ACREEDOR(p_nro_cuenta
in pr_cta_prestamos.nro_cuenta%type default null)
 is

  v_cod_usuario         ge_movimientos.cod_usuario%type:= USER;
  v_fec_actual          ge_calendarios.fec_actual%type  := pae_cnf.fu_obt_fec_actual(5);
  v_mon_local  constant ge_cuentas.cod_moneda%type      := pag_gen.fu_obt_mon_local;
  v_hora                ge_movimientos.hora%type        := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_concepto            ge_movimientos.concepto%type;
  r_mvto                ge_movimientos%rowtype;
  v_redondeo            number(5);
  v_est_cuenta          varchar2(1);
  v_fecha_ant           date;
  v_nro_cuenta          ge_movimientos .nro_cuenta%type ;  -- OMM OCT/2016 DYDMR-5128
  v_can_user            number;
  -- Tipo de registro y tabla para BULK COLLECT
  TYPE rec_movimiento IS RECORD (
    fecha              ge_movimientos.fecha%TYPE,
    hora               ge_movimientos.hora%TYPE,
    cod_usuario        ge_movimientos.cod_usuario%TYPE,
    nro_secuencia      ge_movimientos.nro_secuencia%TYPE,
    fec_valor          ge_movimientos.fec_valor%TYPE,
    monto              ge_movimientos.monto%TYPE,
    nro_cuenta         ge_movimientos.nro_cuenta%TYPE,
    cod_moneda         ge_movimientos.cod_moneda%TYPE,
    cod_oficina        ge_movimientos.cod_oficina%TYPE,
    cod_error          ge_movimientos.cod_error%TYPE,
    cod_retencion      ge_movimientos.cod_retencion%TYPE,
    fec_fin_retencion  ge_movimientos.fec_fin_retencion%TYPE,
    est_cuenta         ge_movimientos.est_cuenta%TYPE,
    estado             ge_movimientos.estado%TYPE,
    cod_causa          ge_movimientos.cod_causa%TYPE,
    cod_banco          ge_movimientos.cod_banco%TYPE,
    cod_ofi_origen     ge_movimientos.cod_ofi_origen%TYPE,
    concepto           ge_movimientos.concepto%TYPE,
    cod_tasa           ge_movimientos.cod_tasa%TYPE,
    val_tasa           ge_movimientos.val_tasa%TYPE,
    cod_rubro          ge_movimientos.cod_rubro%TYPE,
    cod_ref_cambio     ge_movimientos.cod_ref_cambio%TYPE,
    reversado          ge_movimientos.reversado%TYPE,
    cod_usu_reversion  ge_movimientos.cod_usu_reversion%TYPE,
    hor_reversion      ge_movimientos.hor_reversion%TYPE,
    emi_aviso          ge_movimientos.emi_aviso%TYPE,
    cod_tra_padre      ge_movimientos.cod_tra_padre%TYPE,
    cod_mod_padre      ge_movimientos.cod_mod_padre%TYPE,
    cod_mad_padre      ge_movimientos.cod_mad_padre%TYPE,
    cod_transaccion    ge_movimientos.cod_transaccion%TYPE,
    cod_modulo         ge_movimientos.cod_modulo%TYPE,
    cod_modalidad      ge_movimientos.cod_modalidad%TYPE,
    mto_equ_local      ge_movimientos.mto_equ_local%TYPE,
    nro_caja           ge_movimientos.nro_caja%TYPE,
    cotizacion         ge_movimientos.cotizacion%TYPE,
    cod_bco_central    ge_movimientos.cod_bco_central%TYPE,
    nro_documento      ge_movimientos.nro_documento%TYPE,
    nro_documento2     ge_movimientos.nro_documento2%TYPE,
    nro_documento3     ge_movimientos.nro_documento3%TYPE,
    nro_documento4     ge_movimientos.nro_documento4%TYPE,
    protegido          ge_movimientos.protegido%TYPE,
    cod_autorizacion   ge_movimientos.cod_autorizacion%TYPE,
    cod_usu_autorizador ge_movimientos.cod_usu_autorizador%TYPE,
    tip_mov_rubro      ge_movimientos.tip_mov_rubro%TYPE,
    cod_tip_ope_cambio ge_movimientos.cod_tip_ope_cambio%TYPE,
    referencia         ge_movimientos.referencia%TYPE,
    cod_persona        ge_movimientos.cod_persona%TYPE,
    cod_sit_contable   ge_movimientos.cod_sit_contable%TYPE
  );

  TYPE tab_movimiento IS TABLE OF rec_movimiento;
    v_movimientos tab_movimiento := tab_movimiento();

  TYPE cta_rec IS RECORD (
    nro_cuenta       ta_cta_tarjetas.nro_cuenta%TYPE,
    cod_modulo       ta_cta_tarjetas.cod_modulo%TYPE,
    cod_modalidad    ta_cta_tarjetas.cod_modalidad%TYPE,
    cod_oficina      ta_cta_tarjetas.cod_oficina%TYPE,
    cod_moneda       ta_cta_tarjetas.cod_moneda%TYPE,
    sal_tarjeta      ta_cta_tarjetas.sal_procesadora%TYPE,
    new_categoria    ta_cta_tarjetas.cat_automatica%TYPE,
    cotizacion       NUMBER
  );

  TYPE cta_tab IS TABLE OF cta_rec;
  v_cuentas cta_tab;

  -- CIE-349
  v_cod_transaccion     ge_movimientos.cod_transaccion%TYPE := 5924;
  v_cod_modulo          ge_movimientos.cod_modulo%TYPE      := 5;
  TYPE tab_movimientos IS TABLE OF ge_movimientos%ROWTYPE;
  v_ins_movimientos tab_movimientos := tab_movimientos();
  --para update por rowid
  TYPE typ_rowid IS TABLE OF ROWID;
  v_rowids typ_rowid;

  -- coleccion para manejar nro_secuencia por cod_usuario de manera mas equitativa
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;

   TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora t_usu_hor;

  --> Cursor de Movimientos de tarjetas a reversar
  cursor movimientos is
     Select a.fecha,
            a.hora,
            a.cod_usuario,
            a.nro_secuencia,
            a.fec_valor,
            a.monto,
            a.nro_cuenta,
            a.cod_moneda,
            a.cod_oficina,
            a.cod_error,
            a.cod_retencion,
            a.fec_fin_retencion,
            a.est_cuenta,
            a.estado,
            a.cod_causa,
            a.cod_banco,
            a.cod_ofi_origen,
            a.concepto,
            a.cod_tasa,
            a.val_tasa,
            a.cod_rubro,
            a.cod_ref_cambio,
            a.reversado,
            a.cod_usu_reversion,
            a.hor_reversion,
            a.emi_aviso,
            a.cod_tra_padre,
            a.cod_mod_padre,
            a.cod_mad_padre,
            a.cod_transaccion,
            a.cod_modulo,
            a.cod_modalidad,
            a.mto_equ_local,
            a.nro_caja,
            a.cotizacion,
            a.cod_bco_central,
            a.nro_documento,
            a.nro_documento2,
            a.nro_documento3,
            a.nro_documento4,
            a.protegido,
            a.cod_autorizacion,
            a.cod_usu_autorizador,
            a.tip_mov_rubro,
            a.cod_tip_ope_cambio,
            a.referencia,
            a.cod_persona,
            a.cod_sit_contable
       From ta_movimientos_his a
      Where a.nro_Cuenta = Nvl(p_Nro_Cuenta, a.Nro_Cuenta)
        and a.cod_transaccion = v_cod_transaccion
        and a.Fecha = v_Fecha_Ant
        and a.reversado = 'N'
        and a.cod_modulo = v_cod_modulo;

  ---> Cursor de tarjetas para el traspaso de saldo acreedor
  cursor cuentas is
    Select t.Nro_Cuenta,
         Nvl(t.Cod_Modulo, 5) Cod_Modulo,
         t.Cod_Modalidad,
         t.Cod_Oficina,
         t.Cod_Moneda,
         (t.sal_procesadora)*-1 Sal_Tarjeta,
         t.Cat_Automatica New_Categoria,
         Pag_Gen.Fu_Obt_Cotizacion(t.Cod_Moneda,v_fec_actual) Cotizacion
    From Ta_Cta_Tarjetas t
   Where t.Nro_Cuenta = Nvl(p_Nro_Cuenta, t.Nro_Cuenta)
     And t.Estado != 'C'
     And t.Sal_Procesadora < 0
     And NVL(Instr(Fug_Obt_Pardinamico('TAR_PRE_PAGAS'), ','||t.Cod_Modalidad||','),0) = 0
   Order By t.Cod_Oficina;
 
BEGIN

  --REVERSION DEL DIA ANTERIOR

BEGIN
  v_fecha_ant := pag_cal.FU_OBT_FEC_ANT_HAb(v_fec_actual, NULL, 1);

  BEGIN
    SELECT COUNT(*)
      INTO v_can_user
      FROM ba_cod_referencias
     WHERE dominio = 'USU_MOV_CIERRE'
       AND abreviatura = 'MOVCIERRE';
  END;
  
  -- Cargar los datos de movimientos en una colección
  OPEN movimientos;
  LOOP
       FETCH movimientos BULK COLLECT INTO v_movimientos LIMIT 100000;
       EXIT WHEN v_movimientos.COUNT = 0;
       -- Procesar los movimientos para reversión
       FOR i IN 1 .. v_movimientos.COUNT LOOP

       ---------------------------------------------
       -- Control multiUsuarios
       ---------------------------------------------
       v_cod_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
       v_hora:= PAG_CIE.FU_OBT_HORA(v_cod_usuario, 'S_HOR_MOVCIERRE','E');
       ---------------------------------------------
           r_mvto.fecha                  := v_fec_actual;
           r_mvto.hora                   := v_hora;
           r_mvto.cod_usuario            := v_cod_usuario;
           r_mvto.nro_secuencia          := v_movimientos(i).nro_secuencia;
           r_mvto.fec_valor              := v_movimientos(i).fec_valor;
           r_mvto.monto                  := v_movimientos(i).monto * -1; -- Debe de ser negativo
           r_mvto.nro_cuenta             := v_movimientos(i).nro_cuenta;
           r_mvto.cod_moneda             := v_movimientos(i).cod_moneda;
           r_mvto.cod_oficina            := v_movimientos(i).cod_oficina;
           r_mvto.cod_error              := v_movimientos(i).cod_error;
           r_mvto.cod_retencion          := v_movimientos(i).cod_retencion;
           r_mvto.fec_fin_retencion      := v_movimientos(i).fec_fin_retencion;
           r_mvto.est_cuenta             := v_movimientos(i).est_cuenta;
           r_mvto.estado                 := v_movimientos(i).estado;
           r_mvto.cod_causa              := v_movimientos(i).cod_causa;
           r_mvto.cod_banco              := v_movimientos(i).cod_banco;
           r_mvto.cod_ofi_origen         := v_movimientos(i).cod_ofi_origen;
           r_mvto.concepto               := v_movimientos(i).concepto;
           r_mvto.cod_tasa               := v_movimientos(i).cod_tasa;
           r_mvto.val_tasa               := v_movimientos(i).val_tasa;
           r_mvto.cod_rubro              := v_movimientos(i).cod_rubro;
           r_mvto.cod_ref_cambio         := v_movimientos(i).cod_ref_cambio;
           r_mvto.reversado              := 'S';
           r_mvto.cod_usu_reversion      := v_movimientos(i).cod_usuario;
           r_mvto.hor_reversion          := v_movimientos(i).hora;
           r_mvto.emi_aviso              := v_movimientos(i).emi_aviso;
           r_mvto.cod_tra_padre          := v_movimientos(i).cod_tra_padre;
           r_mvto.cod_mod_padre          := v_movimientos(i).cod_mod_padre;
           r_mvto.cod_mad_padre          := v_movimientos(i).cod_mad_padre;
           r_mvto.cod_transaccion        := v_cod_transaccion;
           r_mvto.cod_modulo             := v_cod_modulo;
           r_mvto.cod_modalidad          := v_movimientos(i).cod_modalidad;
           r_mvto.mto_equ_local          := v_movimientos(i).mto_equ_local * -1; -- Debe de ser negativo
           r_mvto.nro_caja               := v_movimientos(i).nro_caja;
           r_mvto.cotizacion             := v_movimientos(i).cotizacion;
           r_mvto.cod_bco_central        := v_movimientos(i).cod_bco_central;
           r_mvto.nro_documento          := v_movimientos(i).nro_documento;
           r_mvto.nro_documento2         := v_movimientos(i).nro_documento2;
           r_mvto.nro_documento3         := v_movimientos(i).nro_documento3;
           r_mvto.nro_documento4         := v_movimientos(i).nro_documento4;
           r_mvto.protegido              := v_movimientos(i).protegido;
           r_mvto.cod_autorizacion       := v_movimientos(i).cod_autorizacion;
           r_mvto.cod_usu_autorizador    := v_movimientos(i).cod_usu_autorizador;
           r_mvto.tip_mov_rubro          := v_movimientos(i).tip_mov_rubro;
           r_mvto.cod_tip_ope_cambio     := v_movimientos(i).cod_tip_ope_cambio;
           r_mvto.referencia             := v_movimientos(i).referencia;
           r_mvto.cod_persona            := v_movimientos(i).cod_persona;
           r_mvto.cod_sit_contable       := v_movimientos(i).cod_sit_contable;
           -- Cargo para un forall
           v_ins_movimientos.EXTEND;
           v_ins_movimientos(v_ins_movimientos.LAST) := r_mvto;

      END LOOP;
  END LOOP;
  CLOSE movimientos;
  -- Insercion a ge_movimientos con FORALL CIE-349
  FORALL i IN v_ins_movimientos.FIRST .. v_ins_movimientos.LAST
    INSERT INTO ge_movimientos(
      fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
      nro_cuenta, cod_moneda, cod_oficina, cod_error, cod_retencion,
      fec_fin_retencion, est_cuenta, estado, cod_causa, cod_banco,
      cod_ofi_origen, concepto, cod_tasa, val_tasa, cod_rubro,
      cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
      emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
      cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local,
      nro_caja, cotizacion, cod_bco_central, nro_documento,
      nro_documento2, nro_documento3, nro_documento4, protegido,
      cod_autorizacion, cod_usu_autorizador, tip_mov_rubro,
      cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable,
      nro_conciliacion
    )
    VALUES (
      v_ins_movimientos(i).fecha, v_ins_movimientos(i).hora, v_ins_movimientos(i).cod_usuario,
      v_ins_movimientos(i).nro_secuencia, v_ins_movimientos(i).fec_valor, v_ins_movimientos(i).monto,
      v_ins_movimientos(i).nro_cuenta, v_ins_movimientos(i).cod_moneda, v_ins_movimientos(i).cod_oficina,
      v_ins_movimientos(i).cod_error, v_ins_movimientos(i).cod_retencion, v_ins_movimientos(i).fec_fin_retencion,
      v_ins_movimientos(i).est_cuenta, v_ins_movimientos(i).estado, v_ins_movimientos(i).cod_causa,
      v_ins_movimientos(i).cod_banco, v_ins_movimientos(i).cod_ofi_origen, v_ins_movimientos(i).concepto,
      v_ins_movimientos(i).cod_tasa, v_ins_movimientos(i).val_tasa, v_ins_movimientos(i).cod_rubro,
      v_ins_movimientos(i).cod_ref_cambio, v_ins_movimientos(i).reversado, v_ins_movimientos(i).cod_usu_reversion,
      v_ins_movimientos(i).hor_reversion, v_ins_movimientos(i).emi_aviso, v_ins_movimientos(i).cod_tra_padre,
      v_ins_movimientos(i).cod_mod_padre, v_ins_movimientos(i).cod_mad_padre, v_ins_movimientos(i).cod_transaccion,
      v_ins_movimientos(i).cod_modulo, v_ins_movimientos(i).cod_modalidad, v_ins_movimientos(i).mto_equ_local,
      v_ins_movimientos(i).nro_caja, v_ins_movimientos(i).cotizacion, v_ins_movimientos(i).cod_bco_central,
      v_ins_movimientos(i).nro_documento, v_ins_movimientos(i).nro_documento2, v_ins_movimientos(i).nro_documento3,
      v_ins_movimientos(i).nro_documento4, v_ins_movimientos(i).protegido, v_ins_movimientos(i).cod_autorizacion,
      v_ins_movimientos(i).cod_usu_autorizador, v_ins_movimientos(i).tip_mov_rubro,
      v_ins_movimientos(i).cod_tip_ope_cambio, v_ins_movimientos(i).referencia,
      v_ins_movimientos(i).cod_persona, v_ins_movimientos(i).cod_sit_contable,
      v_ins_movimientos(i).nro_conciliacion
  );
  -- cargo rowid de lo que se va a actualizar CIE-349
  SELECT rowid
    BULK COLLECT INTO v_rowids
    FROM ta_movimientos_his
   WHERE fecha = v_fecha_ant
     AND cod_transaccion = v_cod_transaccion
     AND reversado = 'N';

  -- UPDATE A TA_MOVIMIENTOS_HIS con FORALL + rowid.. CIE-349  
  FORALL i IN v_ins_movimientos.FIRST .. v_ins_movimientos.LAST
    UPDATE ta_movimientos_his
       SET reversado = 'S',
           cod_usu_reversion = v_ins_movimientos(i).cod_usu_reversion,
           hor_reversion     = v_ins_movimientos(i).hor_reversion
     WHERE rowid = v_rowids(i);
  EXCEPTION
     when others then
       raise_application_error(-20282, 'Error. Tras.Sal.Acre.Tarjetas(Reversión.): '|| 'm.nro_cuenta:'||v_nro_cuenta||' - '||sqlerrm);
  END;
  
   --*************FIN DE REVERSION **********************

   --*************TRASPASO_SALDO **********************
  BEGIN

  -- Cargar los datos de `cuentas` en una colección
  OPEN cuentas;
  FETCH cuentas BULK COLLECT INTO v_cuentas LIMIT 100000;
  CLOSE cuentas;

  --->insercion de Movimientos
  -- Procesar cada cuenta de la colección
  FOR j IN 1 .. v_cuentas.COUNT LOOP

    ---------------------------------------------
    -- Control multiUsuarios
    ---------------------------------------------  
    v_cod_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
     
    ---------------------------------------------
    -- primera vez para cada user es secuencia 0
    IF NOT v_usu_secuencia.EXISTS(v_cod_usuario) THEN
      v_usu_secuencia(v_cod_usuario) := 0;
      v_usu_hora(v_cod_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_cod_usuario, 'S_HOR_MOVCIERRE','E');
    END IF;
    ---------------------------------------------

    IF v_usu_secuencia(v_cod_usuario) >= 995 THEN
       v_usu_secuencia(v_cod_usuario) := 1;
       v_usu_hora(v_cod_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_cod_usuario, 'S_HOR_MOVCIERRE','E');
    ELSE
      -- Se incrementa la secuencia del usuario
      v_usu_secuencia(v_cod_usuario) := v_usu_secuencia(v_cod_usuario) + 1;
    END IF;

    v_concepto := 'TRASPASO SALDO ACREEDOR TC';
    r_mvto.nro_secuencia      := v_usu_secuencia(v_cod_usuario);
    r_mvto.cod_usuario        := v_cod_usuario;
    r_mvto.hora               := v_usu_hora(v_cod_usuario);
    r_mvto.cod_modulo         := v_cuentas(j).cod_modulo;
    r_mvto.cod_modalidad      := v_cuentas(j).cod_modalidad;
    r_mvto.cod_oficina        := v_cuentas(j).cod_oficina;
    r_mvto.nro_cuenta         := v_cuentas(j).nro_cuenta;
    r_mvto.cod_moneda         := v_cuentas(j).cod_moneda;
    r_mvto.cod_tra_padre      := 945;
    r_mvto.cod_transaccion    := 5924;
    r_mvto.fecha              := v_fec_actual;
    r_mvto.fec_valor          := v_fec_actual;
    r_mvto.monto              := v_cuentas(j).sal_tarjeta;
    r_mvto.estado             := 'N';
    r_mvto.est_cuenta         := v_est_cuenta;
    r_mvto.cod_ofi_origen     := v_cuentas(j).cod_oficina;
    r_mvto.concepto           := v_concepto;
    r_mvto.reversado          := 'N';
    r_mvto.emi_aviso          := 'N';
    r_mvto.protegido          := 'N';
    r_mvto.cod_mod_padre      := v_cuentas(j).cod_modulo;
    r_mvto.cod_mad_padre      := v_cuentas(j).cod_modalidad;
    r_mvto.referencia         := 'TRAS.SALD.ACREED';

    IF v_cuentas(j).cod_moneda = v_mon_local THEN
      r_mvto.mto_equ_local := NULL;
      r_mvto.cotizacion := NULL;
    ELSE
        begin
          select d.val_parametro
            into v_redondeo
            from ge_par_dinamicos d
           where d.parametro = 'VAL_RED_MON_EXTRANJERA'
             and d.cod_modulo =  v_cuentas(j).cod_modulo
             and d.cod_modalidad = v_cuentas(j).cod_modalidad
             and d.cod_moneda = v_mon_local;
        exception
          when others then
            v_redondeo := 0;
        end;
      --v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cuentas(j).cod_modulo, v_cuentas(j).cod_modalidad, v_mon_local);
      r_mvto.mto_equ_local := ROUND(v_cuentas(j).new_categoria * v_cuentas(j).cotizacion, v_redondeo);
      r_mvto.cotizacion := v_cuentas(j).cotizacion;
    END IF;

    -- Inserción en la tabla ge_movimientos
    pag_gen.pr_ins_ge_movimiento(r_mvto);
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20282, 'Error. Tras.Sal.Acre.Tarjetas(Traspaso): ' || SQLERRM);
   END;
END PRT_TRA_SAL_ACREEDOR;
