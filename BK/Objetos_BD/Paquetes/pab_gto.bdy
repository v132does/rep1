CREATE OR REPLACE PACKAGE BODY IT.PAB_GTO IS

-- Obtiene el c�digo del rubro contable.
FUNCTION FU_OBT_RUB_CONTABLE (p_cod_tip_asientos      IN NUMBER,
                              p_cod_moneda            IN VARCHAR2,
                              p_cod_persona           in varchar2,
                              p_cod_plazo             IN VARCHAR2,
                              p_tip_movimiento        IN VARCHAR2,
                              p_est_cuenta            in varchar2 default null,
                              p_tip_renovacion        in varchar2 default null,
                              p_cat_automatica        in number default null,
                              p_tip_interes           in varchar2 default null,
                              p_tip_cuenta            in varchar2 default null,
                              p_cod_sit_contable      ge_tip_asientos.cod_sit_contable%type default null,
                              p_cod_sec_credito       pr_cta_prestamos.cod_sec_credito%type default null)
RETURN VARCHAR2 IS
-- Variables.
v_cod_tip_deudor      NUMBER(4);
v_cod_pro_contable    NUMBER(3) := NULL;
v_ind_deudor          VARCHAR2(1);
v_ind_plazo           VARCHAR2(1);
v_ind_producto        VARCHAR2(1);
v_cod_rubro           VARCHAR2(20);
v_cod_sec_contable    VARCHAR2(01);
v_residente           VARCHAR2(1);

BEGIN
   /* busco el sector del cliente */
   Begin
   SELECT cod_sec_contable, cod_tip_deudor, residente
     into v_cod_sec_contable, v_cod_tip_deudor, v_residente
     from ge_clientes
    where cod_persona = p_cod_persona;
   Exception
      when others then
         v_cod_sec_contable := 'N';
         v_cod_tip_deudor   := 2;
         v_residente        := 'S';
   end;

   /* busco la cuenta contable que le corresponde */
   SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
     INTO v_ind_plazo,v_ind_deudor, v_cod_rubro, v_ind_producto
     FROM ge_tip_asientos
    WHERE cod_tip_asiento = p_cod_tip_asientos
      AND cod_moneda = p_cod_moneda
      AND (cod_sec_contable is null or cod_sec_contable = v_cod_sec_contable)
      and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
      and (tip_interes is null or tip_interes = p_tip_interes)
      --and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
      and ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
           (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)))
      and (cat_automatica is null or cat_automatica = p_cat_automatica)
      and (est_cuenta is null or est_cuenta = p_est_cuenta)
      AND (ind_residente = 'X' OR ind_residente = v_residente)
      AND tip_movimiento = p_tip_movimiento
      and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
      AND nro_linea =  ( Select min(nro_linea)
                           FROM ge_tip_asientos
                          WHERE cod_tip_asiento = p_cod_tip_asientos
                            AND cod_moneda = p_cod_moneda
                            AND (cod_sec_contable is null or cod_sec_contable = v_cod_sec_contable)
                            and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
                            and (tip_interes is null or tip_interes = p_tip_interes)
                            and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
                            and (cat_automatica is null or cat_automatica = p_cat_automatica)
                            and (est_cuenta is null or est_cuenta = p_est_cuenta)
                            AND (ind_residente = 'X' OR ind_residente = v_residente)
                            and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
                            AND tip_movimiento = p_tip_movimiento);
   IF v_ind_plazo = 'S' then
      v_cod_rubro := substr(v_cod_rubro,1,2)||p_cod_plazo||
                    substr(v_cod_rubro,4,12);
   END IF;
   IF v_ind_deudor = 'S' OR substr(v_cod_rubro,9,2) = 'TD' then
      v_cod_rubro := substr(v_cod_rubro,1,8)||
                    (ltrim(to_char(v_cod_tip_deudor,'00')))||
                    substr(v_cod_rubro,11,5);
   END IF;
   ---Reemplaza el codigo del producto -----------------------
   IF v_IND_PRODUCTO = 'S' THEN
      v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                     LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                     SUBSTR(v_cod_rubro,14,2);
   END IF;
   IF substr(v_cod_rubro,11,3)  = 'SEC' THEN
      -- es solo para prestamos, para contabilizar por sector
      v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                    LTRIM(TO_CHAR(FUP_OBT_SEC_RUBRO(p_cod_sec_credito),'000'))||
                    SUBSTR(v_cod_rubro,14,2);
   END IF;
   return v_cod_rubro;
EXCEPTION
   WHEN OTHERS THEN
        v_cod_rubro := NULL;
        return v_cod_rubro;
END;

-- Obtiene la relaci�n de los c�digos de centros de costos.
FUNCTION FU_OBT_REL_CEN_COSTOS(p_cod_cen_costos in ba_areas.cod_area%type)
RETURN NUMBER
AS
v_cod_cen_costos ba_areas.cod_area%type;
BEGIN
   SELECT bc.val_maximo
     INTO v_cod_cen_costos
     FROM ba_cod_referencias bc
    WHERE bc.dominio = 'REL_COD_CEN_COSTOS'
      AND bc.val_minimo = p_cod_cen_costos;

   RETURN v_cod_cen_costos;
EXCEPTION
   WHEN OTHERS THEN
        v_cod_cen_costos := NULL;
        return v_cod_cen_costos;
END;


-- Obtiene los movimientos del modulo de Proveedores.
PROCEDURE PR_GEN_PROVEEDORES IS

   -- Variables.
   v_fec_actual    ge_movimientos.fecha%type      := pag_cal.fu_obt_fec_actual(1);
   v_cod_mon_local ge_movimientos.cod_moneda%type := pag_gen.fu_obt_mon_local;
   -- Cursores.
   CURSOR c_pag_proveedores IS
      SELECT a.cod_compra, a.cod_ent_proveedor, a.nro_factura, v_cod_mon_local cod_moneda, a.fec_pago,
             a.nro_cta_referencia, b.cod_oficina, b.cod_area,
             (CASE WHEN a.cod_moneda = v_cod_mon_local THEN b.val_total ELSE pag_gen.fu_con_mon_a_moneda(a.cod_moneda,v_cod_mon_local,b.val_total,NULL,NVL(a.fec_pago,v_fec_actual),NULL) END) val_total,
             c.cod_modulo, c.cod_modalidad, c.cod_transaccion,
             fub_obt_rub_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion, a.cod_moneda, null, null, 'D') cod_rubro
        FROM pv_compras a, pv_compras_det c, pv_com_oficinas b
       WHERE a.cod_compra = b.cod_compra
         AND a.cod_compra = c.cod_compra
         AND c.nro_linea = b.nro_linea
         AND a.ind_pagado = 'S'
         AND a.estado = 'P'
         AND to_char(a.fec_pago,'mmyyyy') = to_char(v_fec_actual,'mmyyyy');

BEGIN
   FOR reg IN c_pag_proveedores LOOP
      -- Valido que el movimiento corresponda a un Gastos.
      IF substr(reg.cod_rubro,1,1) = '7' THEN
         -- Inserto en la tabla de derrama de gastos.
         BEGIN
            INSERT INTO cb_inf_der_gastos(fecha, cod_oficina, cod_rubro, cod_area, cod_modulo, cod_modalidad,
                                         cod_transaccion, cod_moneda, importe, cod_tip_distribucion, referencia,
                                         fec_proceso, hor_proceso)
                 VALUES (v_fec_actual, reg.cod_oficina, reg.cod_rubro, reg.cod_area, reg.cod_modulo, reg.cod_modalidad,
                         reg.cod_transaccion, reg.cod_moneda, nvl(reg.val_total,0), null, null, reg.fec_pago, null);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   END LOOP;
END;

-- Validaci�n del proceso de importaci�n de la parametrizaci�n de los tipos de distribuci�n.
PROCEDURE PR_VAL_PAR_GASTOS IS

-- Variables.
v_cod_tip_distribucion cb_par_der_gastos.cod_tip_distribucion%TYPE := NULL;
v_cod_tip_asientos     cb_par_der_gastos.cod_tip_asientos%TYPE := NULL;
v_msj                  varchar2(250);
BEGIN
   -- Valida Tipos de Distribuci�n.
   BEGIN
      SELECT MIN(cp.cod_tip_distribucion)
        INTO v_cod_tip_distribucion
        FROM cb_par_der_gastos cp
       WHERE NOT EXISTS (SELECT 1
                           FROM ba_cod_referencias bc
                          WHERE bc.dominio = 'TIP_DIS_CEN_COSTOS'
                            AND bc.val_minimo = cp.cod_tip_distribucion);

      IF v_cod_tip_distribucion IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DER_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'El Tipo de Distribuci�n '||v_cod_tip_distribucion||' no se encuentra registrado en la Referencia General (TIP_DIS_CEN_COSTOS).'||' '||sqlerrm);
      END IF;
   END;

   -- Valida el c�digo de transacci�n.
   BEGIN
      SELECT MIN(cp.cod_tip_asientos)
        INTO v_cod_tip_asientos
        FROM cb_par_der_gastos cp
       WHERE NOT EXISTS (SELECT 1
                           FROM ge_tip_asientos gt
                          WHERE gt.cod_tip_asiento = cp.cod_tip_asientos);

      IF v_cod_tip_asientos IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DER_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'El C�digo de Asiento: '||v_cod_tip_asientos||' no se encuentra registrado en el sistema. Verifique!!!'||' '||sqlerrm);
      END IF;
   END;

EXCEPTION
   WHEN OTHERS THEN
      sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DER_GASTOS', v_msj);
      IF v_msj IS NOT NULL THEN
         raise_application_error(-20000, v_msj);
      END IF;
      raise_application_error(-20000, 'Error: '||sqlerrm);
END;

-- Validaci�n del proceso de importaci�n de la parametrizaci�n del destino del proceso de derrama de gastos.
PROCEDURE PR_VAL_TIP_GASTOS IS

-- Variables.
v_cod_tip_distribucion cb_par_dis_gastos.cod_tip_distribucion%TYPE := NULL;
v_cod_oficina          cb_par_dis_gastos.cod_oficina%TYPE := NULL;
v_cod_ofi_movimiento   ba_oficinas.cod_oficina%type            := 31;
v_cod_ofi_coap         ba_oficinas.cod_oficina%type            := 99;
v_msj                  varchar2(250);

-- Cursores.
CURSOR c_porcentajes IS
   SELECT cp.cod_tip_distribucion, ROUND(SUM(NVL(cp.porcentaje,0)),8) porcentaje
     FROM cb_par_dis_gastos cp
    WHERE cp.porcentaje IS NOT NULL
      AND cp.cod_tip_distribucion NOT IN (2,3)
    GROUP BY cp.cod_tip_distribucion;

BEGIN
   -- Valida Tipos de Distribuci�n.
   BEGIN
      SELECT MIN(cp.cod_tip_distribucion)
        INTO v_cod_tip_distribucion
        FROM cb_par_dis_gastos cp
       WHERE NOT EXISTS (SELECT 1
                           FROM ba_cod_referencias bc
                          WHERE bc.dominio = 'TIP_DIS_CEN_COSTOS'
                            AND bc.val_minimo = cp.cod_tip_distribucion);

      IF v_cod_tip_distribucion IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'El Tipo de Distribuci�n '||v_cod_tip_distribucion||' no se encuentra registrado en la Referencia General (TIP_DIS_CEN_COSTOS).'||' '||sqlerrm);
      END IF;
   END;

   -- Valida si el Tipo de Distribuci�n es Porcentaje Fijo, el valor asignado debe ser igual a 100%.
   BEGIN
      FOR reg IN c_porcentajes LOOP
         IF NVL(reg.porcentaje,0) <> 1 THEN
            sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
            IF v_msj IS NOT NULL THEN
               raise_application_error(-20000, v_msj);
            END IF;
            raise_application_error(-20000, 'El Total Porcentual del Tipo de Distribuci�n: '||reg.cod_tip_distribucion||' es incorrecto, la suma de los valores porcentuales debe ser igual al 100%. '||' '||sqlerrm);
         END IF;
      END LOOP;
   END;

   -- Valida el Tipo de Derrama por Volumen de Activos.
   BEGIN
      SELECT MIN(V.COD_OFICINA)
        INTO v_cod_oficina
        FROM (
             SELECT cp.cod_oficina cod_oficina, COUNT(1) cantidad
               FROM cb_par_dis_gastos cp
              WHERE cp.cod_tip_distribucion = 3
              GROUP BY cp.cod_oficina
             HAVING COUNT(cp.cod_oficina) > 1) v;

      IF v_cod_oficina IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'El C�digo de Oficina: '||v_cod_oficina||' solamente debe poseer un C�digo de Centro de Costo destino asignado para el Tipo de Distribuci�n 3 - Por Volumen de Activos.'||' '||sqlerrm);
      END IF;
   END;

   -- Valida las sucursales asignadas al Detalle.
   v_cod_tip_distribucion := NULL;
   BEGIN
      SELECT MIN(cp.cod_tip_distribucion)
        INTO v_cod_tip_distribucion
        FROM cb_par_dis_gastos cp
       WHERE cp.cod_oficina IN (v_cod_ofi_movimiento,v_cod_ofi_coap);

      IF v_cod_tip_distribucion IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'Los c�digos de oficinas 31 - ADMINISTRACION CENTRAL y 99 - COAP, no pueden ser asignados al Tipo de Distribuci�n: '||v_cod_tip_distribucion||'.'||' '||sqlerrm);
      END IF;
   END;

   -- Valida el C�digo de Oficina.
   v_cod_oficina := NULL;
   BEGIN
      SELECT MIN(cp.cod_oficina)
        INTO v_cod_oficina
        FROM cb_par_dis_gastos cp
       WHERE NOT EXISTS (SELECT 1 FROM ba_oficinas ba WHERE ba.cod_oficina = cp.cod_oficina);

      IF v_cod_oficina IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'No se encuentra registrado en el sistema, el C�digo de Oficina: '||v_cod_oficina||'.'||' '||sqlerrm);
      END IF;
   END;

   -- Valida los tipos de Distribuci�n.
   v_cod_tip_distribucion := NULL;
   BEGIN
      SELECT MIN(cp.cod_tip_distribucion)
        INTO v_cod_tip_distribucion
        FROM cb_par_dis_gastos cp
       WHERE cp.cod_tip_distribucion IN (2,3)
         AND cp.porcentaje > 0;

      IF v_cod_tip_distribucion IS NOT NULL THEN
         sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
         IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
         END IF;
         raise_application_error(-20000, 'El Porcentaje del Tipo de Distribuci�n '||v_cod_tip_distribucion||' se calcula de forma autom�tica, el valor del mismo debe ser igual a 0(Cero).'||' '||sqlerrm);
      END IF;
   END;

EXCEPTION
   WHEN OTHERS THEN
      sql_util.ejecute_dml('TRUNCATE TABLE CB_PAR_DIS_GASTOS', v_msj);
      IF v_msj IS NOT NULL THEN
         raise_application_error(-20000, v_msj);
      END IF;
      raise_application_error(-20000, 'Error: '||sqlerrm);
END;

/* Procedimiento que inserta asientos manuales. */
PROCEDURE PR_INS_ASI_MANUALES(rp_bamde IN cb_asi_futuros_det%ROWTYPE)
IS
BEGIN
   -- Inserto en la cabecera.
   UPDATE cb_asi_futuros cb
      SET cb.tot_control = cb.tot_control + rp_bamde.mto_mon_local
    WHERE cb.nro_asiento = rp_bamde.nro_asiento
      AND cb.fecha = rp_bamde.fecha
      AND cb.cod_oficina = rp_bamde.cod_oficina;

   IF SQL%NOTFOUND THEN

      INSERT INTO cb_asi_futuros
         (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
          actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado)
      VALUES
         (rp_bamde.cod_oficina, rp_bamde.nro_asiento, substr(user,1,10) , rp_bamde.fecha,
          2, 21, rp_bamde.mto_mon_local, 'N','N',rp_bamde.cod_oficina, 'N', 'N');
   END IF;
   -- Inserto el detalle.
   INSERT INTO cb_asi_futuros_det
      (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
       mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
       distribuido, ref_movimiento, cod_modulo)
   VALUES
      (rp_bamde.fecha, rp_bamde.cod_oficina, rp_bamde.nro_asiento, rp_bamde.nro_linea,
       rp_bamde.cod_rubro, rp_bamde.tip_movimiento, rp_bamde.mto_mon_rubro,
       rp_bamde.mto_mon_local, rp_bamde.descripcion, rp_bamde.referencia, rp_bamde.protegido,
       rp_bamde.actualizado, rp_bamde.val_cotizacion, rp_bamde.distribuido,
       rp_bamde.ref_movimiento, rp_bamde.cod_modulo);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Ins.cb_asi_futuros_det ' || rp_bamde.nro_asiento || '-' ||
                               rp_bamde.referencia || '-' || SQLERRM);
END;

PROCEDURE PR_INS_DER_GASTOS(p_cod_fecha cb_inf_der_gastos.fecha%TYPE,
                            p_cod_oficina cb_inf_der_gastos.cod_oficina%TYPE,
                            p_cod_rubro cb_inf_der_gastos.cod_rubro%TYPE,
                            p_cod_area cb_inf_der_gastos.cod_area%TYPE,
                            p_cod_modulo cb_inf_der_gastos.cod_modulo%TYPE,
                            p_cod_modalidad cb_inf_der_gastos.cod_modalidad%TYPE,
                            p_cod_transaccion cb_inf_der_gastos.cod_transaccion%TYPE,
                            p_cod_moneda cb_inf_der_gastos.cod_moneda%TYPE,
                            p_importe cb_inf_der_gastos.importe%TYPE,
                            p_cod_tip_distribucion cb_inf_der_gastos.cod_tip_distribucion%TYPE,
                            p_cod_referencia cb_inf_der_gastos.referencia%TYPE) IS

BEGIN
   -- Inserto los registros en la tabla.
   INSERT INTO cb_inf_der_gastos (fecha, cod_oficina, cod_rubro, cod_area, cod_modulo, cod_modalidad, cod_transaccion,
                                  cod_moneda, importe, cod_tip_distribucion, referencia)
        VALUES (p_cod_fecha, p_cod_oficina, p_cod_rubro, p_cod_area, p_cod_modulo, p_cod_modalidad, p_cod_transaccion,
                p_cod_moneda, p_importe, p_cod_tip_distribucion, p_cod_referencia);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Ins.cb_inf_der_gastos '|| SQLERRM);
END;

-- Proceso que realiza la derrama de gastos.
PROCEDURE PR_PRO_DIS_GASTOS IS

   -- Variables.
   r_bamde               cb_asi_futuros_det%ROWTYPE;
   r_gtasi               ge_tip_asientos%ROWTYPE;
   v_cod_moneda          ba_monedas.cod_moneda%TYPE;
   v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_cod_oficina         cb_asientos_det.cod_oficina%TYPE;
   v_importe             cb_asientos_det.mto_mon_local%type;
   v_mto_mon_local       cb_asientos_det.mto_mon_local%type;
   v_mto_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
   v_mto_rub_local       cb_asientos_det.mto_mon_local%type;
   v_mto_rub_extranjera  cb_asientos_det.mto_mon_rubro%type;
   v_mto_acu_local       cb_asientos_det.mto_mon_local%type;
   v_mto_acu_extranjera  cb_asientos_det.mto_mon_rubro%type;
   v_mto_cotizacion      cb_asientos_det.val_cotizacion%type;
   v_sal_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
   v_sal_mon_local       cb_asientos_det.mto_mon_local%type;
   v_val_cotizacion      cb_asientos_det.val_cotizacion%type;
   v_referencia          cb_asientos_det.referencia%type;
   v_descripcion         cb_asientos_det.descripcion%type;
   v_fec_actual          cb_asientos_det.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_nro_asiento         cb_asientos.nro_asiento%type;
   v_nro_linea           ge_tip_asientos.nro_linea%TYPE;
   v_tip_movimiento      ge_tip_asientos.tip_movimiento%TYPE;
   v_cod_rubro           cb_rubros.cod_rubro%TYPE;
   v_mon_rubro           cb_rubros.cod_moneda%TYPE;
   v_des_transaccion     ge_transacciones.descripcion%TYPE;
   v_cod_mad_padre       ge_modalidades.cod_modalidad%TYPE;
   v_cod_mod_padre       ba_modulos.cod_modulo%TYPE;
   v_cod_modulo          ge_modalidades.cod_modulo%type          := 2;
   v_cod_modalidad       ge_modalidades.cod_modalidad%type       := 21;
   v_cod_ofi_movimiento  ba_oficinas.cod_oficina%type            := 31;
   v_cod_ofi_coap        ba_oficinas.cod_oficina%type            := 99;
   v_can_personas        cb_can_per_gastos.cantidad%type         := 0;
   v_can_per_oficina     cb_can_per_gastos.cantidad%type         := 0;
   v_mto_activo          cb_asientos_det.mto_mon_local%type      := 0;
   v_mto_act_oficina     cb_asientos_det.mto_mon_local%type      := 0;
   v_porcentaje          cb_par_dis_gastos.porcentaje%type;
   v_cod_tip_asientos    ge_tip_asientos.cod_tip_asiento%type;
   v_cen_cos_generico    ba_areas.cod_area%type                  := 999;
   v_sal_balance         cb_sal_oficinas.sal_mon_loc_ant%type    := 0;
   v_sal_distribuido     cb_inf_der_gastos.importe%type          := 0;
   v_cod_referencia      NUMBER(20) := 0;
   v_existe              NUMBER  := 0;
   v_encontro            VARCHAR2(1);
   v_msj                 VARCHAR2(250);


   -- Cursores.
   CURSOR c_der_gastos IS
   SELECT ci.cod_rubro, ci.cod_area, ci.cod_oficina, ci.cod_moneda, NVL(SUM(ci.importe),0) importe,
          bc.val_maximo cod_tip_distribucion, cp.cod_tip_asientos, 1 orden
     FROM cb_inf_der_gastos ci, cb_par_der_gastos cp, ba_cod_referencias bc
    WHERE ci.cod_rubro = cp.cod_rubro
      AND ci.cod_area = bc.val_minimo
      AND bc.dominio = 'DIS_CEN_COS_ESPECIFICOS'
      AND ci.fecha = v_fec_actual
      AND ci.cod_oficina = v_cod_ofi_movimiento
    GROUP BY ci.cod_rubro, ci.cod_area, ci.cod_oficina, ci.cod_moneda, bc.val_maximo, cp.cod_tip_asientos, 1
    UNION ALL
    SELECT ci.cod_rubro, ci.cod_area, ci.cod_oficina, ci.cod_moneda, NVL(SUM(ci.importe),0) importe,
           cp.cod_tip_distribucion, cp.cod_tip_asientos, 2 orden
      FROM cb_inf_der_gastos ci, cb_par_der_gastos cp
     WHERE ci.cod_rubro = cp.cod_rubro
       AND ci.cod_area IN (SELECT bc.val_minimo FROM ba_cod_referencias bc WHERE bc.dominio = 'COD_CEN_COSTOS')
       AND ci.fecha = v_fec_actual
       AND ci.cod_oficina = v_cod_ofi_movimiento
       AND NOT EXISTS (SELECT 1 FROM ba_cod_referencias bc WHERE bc.dominio = 'DIS_CEN_COS_ESPECIFICOS' AND bc.val_minimo = ci.cod_area)
     GROUP BY ci.cod_rubro, ci.cod_area, ci.cod_oficina, ci.cod_moneda, cp.cod_tip_distribucion, cp.cod_tip_asientos, 2
   ORDER BY 8;

   CURSOR c_dis_gastos(p_cod_tip_distribucion IN cb_par_dis_gastos.cod_tip_distribucion%type) IS
   SELECT cd.cod_tip_distribucion, cd.cod_area, cd.cod_oficina, cd.porcentaje
     FROM cb_par_dis_gastos cd
    WHERE cd.cod_tip_distribucion = p_cod_tip_distribucion
    ORDER BY cd.cod_oficina;

   CURSOR c_tip_asientos(p_cod_tip_asiento ge_tip_asientos.cod_tip_asiento%type) IS
   SELECT *
     FROM ge_tip_asientos
    WHERE cod_tip_asiento = p_cod_tip_asiento
      AND cod_moneda = v_cod_moneda
    ORDER BY tip_movimiento DESC;

   CURSOR c_aju_contable IS
   SELECT cp.cod_rubro, cp.cod_tip_distribucion, cp.cod_tip_asientos
     FROM cb_par_der_gastos cp;

   -- Procedimiento que obtiene la moneda del rubro.
   PROCEDURE lp_obt_mon_rubro(p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
                              p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
                              p_encontro   IN OUT VARCHAR2) IS
   BEGIN
      SELECT cod_moneda
        INTO p_cod_moneda
        FROM cb_rubros
       WHERE cod_rubro = p_cod_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_local;
            p_encontro   := 'S';
         ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
            p_encontro   := 'S';
         ELSE
            p_encontro := 'N';
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
   END;

   -- Procedimiento que elimina movimientos que no afectan resultado.
   PROCEDURE lp_eli_movimientos IS
   BEGIN
      DELETE cb_inf_der_gastos ci WHERE ci.fecha = v_fec_actual  AND ci.cod_rubro IS NULL;
      DELETE cb_inf_der_gastos ci WHERE ci.fecha = v_fec_actual  AND substr(ci.cod_rubro,1,1) NOT IN ('6','7');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Elimina Rubros.'||SQLERRM);
   END;

   -- Obtiene la cantidad de personas por Centro de Costo y Oficina.
   FUNCTION lf_obt_can_personas(p_cod_area ba_areas.cod_area%TYPE,
                                p_cod_oficina ba_areas.cod_oficina%TYPE) RETURN NUMBER AS
   -- Variables.
   v_can_personas cb_can_per_gastos.cantidad%type := 0;
   BEGIN
      SELECT NVL(SUM(cc.cantidad),0)
        INTO v_can_personas
        FROM cb_can_per_gastos cc
       WHERE cc.cod_area = p_cod_area
         AND (cc.cod_oficina = p_cod_oficina OR p_cod_oficina IS NULL)
         AND cc.fecha = v_fec_actual
         AND cc.cod_oficina NOT IN (v_cod_ofi_movimiento,v_cod_ofi_coap);

      RETURN v_can_personas;

   EXCEPTION
      WHEN OTHERS THEN
         v_can_personas := 0;
         RETURN v_can_personas;
   END;

   -- Obtiene el Monto Total del Activo por Sucursal sin considerar el Rubro de Interoficinas.
   FUNCTION lf_obt_mto_activo(p_cod_oficina ba_areas.cod_oficina%TYPE) RETURN NUMBER AS
   -- Variables.
   v_mto_activo cb_sal_oficinas.sal_mon_loc_ant%type;
   BEGIN
      SELECT NVL(SUM(NVL(cs.sal_mon_loc_ant,0)+NVL(cs.deb_mon_local,0)-NVL(cs.cre_mon_local,0)),0)
        INTO v_mto_activo
        FROM cb_sal_oficinas cs
       WHERE (cs.cod_oficina = p_cod_oficina OR p_cod_oficina IS NULL)
         AND substr(cs.cod_rubro,6,5) <> '25704'
         AND cs.cod_oficina NOT IN (v_cod_ofi_movimiento,v_cod_ofi_coap);

      RETURN v_mto_activo;

   EXCEPTION
      WHEN OTHERS THEN
         v_mto_activo := 0;
         RETURN v_mto_activo;
   END;

   -- Obtiene el saldo balance del rubro.
   -- Fecha: 27/06/2016.
   -- Requerimiento: CNFDEEVO-46.
   FUNCTION lf_obt_sal_balance(p_cod_rubro cb_asientos_det.cod_rubro%TYPE, p_cod_oficina cb_asientos_det.cod_oficina%type) RETURN NUMBER AS
   -- Variables.
   v_sal_total         cb_sal_oficinas.sal_mon_loc_ant%type := 0;
   v_sal_mes_actual    cb_sal_oficinas.sal_mon_loc_ant%type := 0;
   v_sal_mes_anterior  cb_sal_oficinas.sal_mon_loc_ant%type := 0;
   v_fec_mes_anterior  date;

   BEGIN

      -- Obtengo la fecha de cierre del mes anterior.
      BEGIN
         SELECT pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_pri_dia_mes_habil(2),NULL)
           INTO v_fec_mes_anterior
           FROM dual;
      EXCEPTION
         WHEN OTHERS THEN
            v_fec_mes_anterior := v_fec_actual;
      END;

      -- Obtengo el saldo de mes actual.
      BEGIN
         SELECT NVL(SUM(NVL(cs.sal_mon_loc_ant,0)+NVL(cs.deb_mon_local,0)-NVL(cs.cre_mon_local,0)),0) * (-1)
           INTO v_sal_mes_actual
           FROM cb_sal_oficinas cs
          WHERE cs.cod_rubro = p_cod_rubro
            AND cs.cod_oficina = p_cod_oficina;
      EXCEPTION
         WHEN OTHERS THEN
            v_sal_mes_actual := 0;
      END;

      -- Obtengo el saldo de mes anterior.
      IF to_char(v_fec_actual,'mm') = '01' THEN
         v_sal_mes_anterior := 0;
      ELSE
         BEGIN
            SELECT NVL(SUM(NVL(cs.sal_mon_loc_ant,0)+NVL(cs.deb_mon_local,0)-NVL(cs.cre_mon_local,0)),0) * (-1)
              INTO v_sal_mes_anterior
              FROM cb_sal_oficinas_dia cs
             WHERE cs.cod_rubro = p_cod_rubro
               AND cs.cod_oficina = p_cod_oficina
               AND cs.fecha = v_fec_mes_anterior;
         EXCEPTION
            WHEN OTHERS THEN
               v_sal_mes_anterior := 0;
         END;
      END IF;

      -- Obtengo el saldo estanco.
      v_sal_total := NVL(v_sal_mes_actual,0) - NVL(v_sal_mes_anterior,0);

      RETURN v_sal_total;

   EXCEPTION
      WHEN OTHERS THEN
         v_sal_total := 0;
         RETURN v_sal_total;
   END;

   -- Obtiene el saldo distribuido por rubro.
   -- Fecha: 27/06/2016.
   -- Requerimiento: CNFDEEVO-46.
   FUNCTION lf_obt_sal_distribuido(p_cod_rubro cb_asientos_det.cod_rubro%TYPE, p_cod_oficina cb_asientos_det.cod_oficina%type) RETURN NUMBER AS
   -- Variables.
   v_saldo cb_inf_der_gastos.importe%type := 0;
   BEGIN
      SELECT NVL(SUM(NVL(cs.importe,0)),0)
        INTO v_saldo
        FROM cb_inf_der_gastos cs
       WHERE cs.fecha = v_fec_actual
         AND cs.cod_oficina = p_cod_oficina
         AND cs.cod_rubro = p_cod_rubro;

      RETURN v_saldo;

   EXCEPTION
      WHEN OTHERS THEN
         v_saldo := 0;
         RETURN v_saldo;
   END;

BEGIN

   -- Elimino los datos que no corresponden a rubros de gastos.
   lp_eli_movimientos;

   -- Derrama de Gastos de los Centros de Costos.
   FOR reg IN c_der_gastos LOOP

      -- Asignacion de Valores.
      v_cod_moneda         := reg.cod_moneda;
      v_importe            := 0;
      v_mto_rub_local      := 0;
      v_mto_rub_extranjera := 0;
      v_mto_acu_local      := 0;
      v_mto_acu_extranjera := 0;
      v_porcentaje         := 0;
      v_cod_referencia     := NVL(v_cod_referencia,0) + 1;

      -- Verifico que el tipo de distribuci�n tenga detalle.
      BEGIN
         SELECT COUNT(1)
           INTO v_existe
           FROM cb_par_dis_gastos cp
          WHERE cp.cod_tip_distribucion = reg.cod_tip_distribucion;

         IF v_existe = 0 THEN
            raise_application_error(-20000, 'El C�digo de Distribuci�n '||reg.cod_tip_distribucion||' no posee detalle de distribuci�n de la Derrama de Gastos de Destino.'||' '||sqlerrm);
         END IF;
      END;

      -- Verifica la Moneda.
      IF v_cod_moneda = v_cod_mon_local THEN
         v_mto_rub_local      := round(nvl(reg.importe,0),0);
         v_mto_rub_extranjera := 0;
         v_mto_cotizacion     := 1;
      ELSE
         -- se obtiene la cotizacion de cierre
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         --
         v_mto_rub_local      := round(nvl(reg.importe,0) * v_mto_cotizacion, 0);
         v_mto_rub_extranjera := round(nvl(reg.importe,0), 2);
      END IF;

      -- Determino los valores para c�lcular los porcentajes de acuerdo al tipo de distribuci�n.
      IF reg.cod_tip_distribucion = 2 THEN --Cantidad de Personas.
         FOR reg_can_personas IN c_dis_gastos(reg.cod_tip_distribucion) LOOP
            v_can_personas := NVL(v_can_personas,0) + lf_obt_can_personas(reg_can_personas.cod_area,reg_can_personas.cod_oficina);
         END LOOP;
      ELSIF reg.cod_tip_distribucion = 3 THEN -- Volumen de Activos.
         FOR reg_vol_activos IN c_dis_gastos(reg.cod_tip_distribucion) LOOP
            v_mto_activo := NVL(v_mto_activo,0) + lf_obt_mto_activo(reg_vol_activos.cod_oficina);
         END LOOP;
      END IF;

      -- Obtengo el detalle a distribuir.
      FOR reg_distribucion IN c_dis_gastos(reg.cod_tip_distribucion) LOOP

         v_cod_oficina := reg_distribucion.cod_oficina;
         -- Obtengo el importe a Contabilizar.
         IF reg.cod_tip_distribucion NOT IN (2,3) THEN --Manual.
            -- Obtengo el importe del asiento.
            IF v_cod_moneda = v_cod_mon_local THEN
               v_importe            := ROUND((NVL(v_mto_rub_local,0) * NVL(reg_distribucion.porcentaje,1)),0);
               v_mto_mon_local      := ROUND(NVL(v_importe,0),0);
               v_mto_mon_extranjera := 0;
               v_mto_cotizacion     := 1;
            ELSE
               v_importe            := ROUND((NVL(v_mto_rub_extranjera,0) * NVL(reg_distribucion.porcentaje,1)),2);
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
               --
               v_mto_mon_local      := ROUND(NVL(v_importe,0) * v_mto_cotizacion, 0);
               v_mto_mon_extranjera := ROUND(NVL(v_importe,0), 2);
            END IF;
         ELSIF reg.cod_tip_distribucion = 2 THEN --Cantidad de Personas.
            -- Obtengo el porcenta que sera aplicado a la oficina.
            v_can_per_oficina := lf_obt_can_personas(reg_distribucion.cod_area,reg_distribucion.cod_oficina);
            IF v_can_per_oficina <> 0 THEN
               v_porcentaje := round((v_can_per_oficina / v_can_personas),8);
            ELSE
               v_porcentaje := 0;
            END IF;

            -- Obtengo el importe del asiento.
            IF v_cod_moneda = v_cod_mon_local THEN
               v_importe            := ROUND((NVL(v_mto_rub_local,0) * NVL(v_porcentaje,1)),0);
               v_mto_mon_local      := round(nvl(v_importe,0),0);
               v_mto_mon_extranjera := 0;
               v_mto_cotizacion     := 1;
            ELSE
               v_importe            := ROUND((NVL(v_mto_rub_extranjera,0) * NVL(v_porcentaje,1)),2);
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
               --
               v_mto_mon_local      := round(nvl(v_importe,0) * v_mto_cotizacion, 0);
               v_mto_mon_extranjera := round(nvl(v_importe,0), 2);
            END IF;

         ELSIF reg.cod_tip_distribucion = 3 THEN -- Volumen de Activos.
            -- Obtengo el porcenta que sera aplicado a la oficina.
            v_mto_act_oficina := lf_obt_mto_activo(reg_distribucion.cod_oficina);
            IF v_mto_act_oficina <> 0 THEN
               v_porcentaje := round((nvl(v_mto_act_oficina,0) / nvl(v_mto_activo,0)),8);
            ELSE
               v_porcentaje := 0;
            END IF;

            -- Obtengo el importe del asiento.
            IF v_cod_moneda = v_cod_mon_local THEN
               v_importe            := ROUND((NVL(v_mto_rub_local,0) * NVL(v_porcentaje,1)),0);
               v_mto_mon_local      := round(nvl(v_importe,0),0);
               v_mto_mon_extranjera := 0;
               v_mto_cotizacion     := 1;
            ELSE
               v_importe            := ROUND((NVL(v_mto_rub_extranjera,0) * NVL(v_porcentaje,1)),2);
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
               --
               v_mto_mon_local      := round(nvl(v_importe,0) * v_mto_cotizacion, 0);
               v_mto_mon_extranjera := round(nvl(v_importe,0), 2);
            END IF;
         END IF;

         -- Asigno los valores a las variables.
         v_mto_acu_local      := NVL(v_mto_acu_local,0) + NVL(v_mto_mon_local,0);
         v_cod_tip_asientos   := reg.cod_tip_asientos;

         -- Genero el asiento del Rubro Contable de Derrama.
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos(reg.cod_tip_asientos);
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            --
            v_encontro := 'S';
            v_cod_rubro:= r_gtasi.cod_rubro;
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               v_mon_rubro := v_cod_mon_local;
            END IF;
            --
            IF v_mon_rubro = v_cod_mon_local THEN
               v_sal_mon_extranjera := 0;
               v_val_cotizacion     := 1;
            ELSE
               v_sal_mon_extranjera := v_mto_mon_extranjera;
               v_val_cotizacion     := v_mto_cotizacion;
            END IF;
            -- Ve el tipo de movimiento.
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF v_mto_mon_local > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               v_sal_mon_local  := v_mto_mon_local;
            ELSE
               v_sal_mon_local      := v_mto_mon_local * -1;
               v_sal_mon_extranjera := v_sal_mon_extranjera * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            -- Obtengo el n�mero de asiento.
            v_nro_linea := 0;
            v_nro_asiento := fub_obt_sig_nro_asi_futuro((case when v_tip_movimiento = 'C' then v_cod_ofi_movimiento else v_cod_oficina end), v_fec_actual);
            --
            v_referencia      := 'DER.GTO.';
            v_descripcion     := substr(v_des_transaccion, 1, 60);
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            --
            IF v_sal_mon_local <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := (case when v_tip_movimiento = 'C' then v_cod_ofi_movimiento else v_cod_oficina end);
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := v_cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
               r_bamde.mto_mon_local  := v_sal_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               r_bamde.cod_modulo     := v_cod_modulo;
               pr_ins_asi_manuales(r_bamde);

               -- Inserto el registro en la tabla cb_inf_der_gastos.
               IF v_tip_movimiento = 'C' THEN
                  pr_ins_der_gastos(v_fec_actual, v_cod_ofi_movimiento, v_cod_rubro, reg.cod_area, v_cod_modulo, v_cod_modalidad,
                                    reg.cod_tip_asientos, reg.cod_moneda, v_sal_mon_local, reg.cod_tip_distribucion, v_cod_referencia);
               ELSE
                  pr_ins_der_gastos(v_fec_actual, v_cod_oficina, v_cod_rubro, reg_distribucion.cod_area, v_cod_modulo, v_cod_modalidad,
                                    reg.cod_tip_asientos, reg.cod_moneda, v_sal_mon_local, reg.cod_tip_distribucion, v_cod_referencia);
               END IF;
            END IF;

            -- Genero los movimientos de interoficinas.
            IF v_tip_movimiento = 'D' THEN
               v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,v_cod_ofi_movimiento);
               v_cod_rubro    := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_ofi_movimiento,'000')) || substr(v_cod_rubro, 14, 2);
            ELSE
               v_cod_rubro    := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,v_cod_oficina);
               v_cod_rubro    := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina,'000')) || substr(v_cod_rubro, 14, 2);
            END IF;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_cod_moneda, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || v_cod_rubro;
               IF substr(v_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_moneda := v_cod_mon_local;
               END IF;
            END IF;
            v_descripcion := substr(TRIM(v_des_transaccion) || '(Inter of)', 1, 60);
            IF v_tip_movimiento = 'C' THEN
               v_tip_movimiento := 'D';
            ELSE
               v_tip_movimiento := 'C';
            END IF;
            IF v_sal_mon_local <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := (case when v_tip_movimiento = 'C' then v_cod_oficina else v_cod_ofi_movimiento end);
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := v_cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
               r_bamde.mto_mon_local  := v_sal_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               r_bamde.cod_modulo     := v_cod_modulo;
               pr_ins_asi_manuales(r_bamde);
            END IF;
         END LOOP;
      END LOOP;
      -- Ajuste de derrama por Rubro y Centro de Costos.
      IF nvl(v_mto_rub_extranjera,0) <> nvl(v_mto_acu_extranjera,0) OR
         nvl(v_mto_rub_local,0) <> nvl(v_mto_acu_local,0) THEN

         -- Obtengo el importe del asiento.
         IF v_cod_moneda = v_cod_mon_local THEN
            v_importe            := ROUND((NVL(v_mto_rub_local,0) - NVL(v_mto_acu_local,0)),0);
            v_mto_mon_local      := ROUND(NVL(v_importe,0),0);
            v_mto_mon_extranjera := 0;
            v_mto_cotizacion     := 1;
         ELSE
            v_importe            := ROUND((NVL(v_mto_rub_extranjera,0) - NVL(v_mto_acu_extranjera,0)),2);
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --
            v_mto_mon_local      := ROUND(NVL(v_importe,0) * v_mto_cotizacion, 0);
            v_mto_mon_extranjera := ROUND(NVL(v_importe,0), 2);
         END IF;

         -- Obtengo el n�mero de asiento.
         v_nro_linea := 0;
         v_nro_asiento := fub_obt_sig_nro_asi_futuro(v_cod_ofi_movimiento, v_fec_actual);
         -- Genero el asiento.
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos(v_cod_tip_asientos);
         LOOP
            FETCH c_tip_asientos
            INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            --
            v_encontro := 'S';
            v_cod_rubro:= r_gtasi.cod_rubro;
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               v_mon_rubro := v_cod_mon_local;
            END IF;
            --
            IF v_mon_rubro = v_cod_mon_local THEN
               v_sal_mon_extranjera := 0;
               v_val_cotizacion     := 1;
            ELSE
               v_sal_mon_extranjera := v_mto_mon_extranjera;
               v_val_cotizacion     := v_mto_cotizacion;
            END IF;
            -- Ve el tipo de movimiento.
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF v_mto_mon_local > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               v_sal_mon_local  := v_mto_mon_local;
            ELSE
               v_sal_mon_local      := v_mto_mon_local * -1;
               v_sal_mon_extranjera := v_sal_mon_extranjera * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            --
            v_referencia      := 'DER.GTO.AJ';
            v_descripcion     := substr(v_des_transaccion, 1, 60);
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            --
            IF v_sal_mon_local <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               -- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := v_cod_ofi_movimiento;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := v_cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_sal_mon_extranjera;
               r_bamde.mto_mon_local  := v_sal_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               r_bamde.cod_modulo     := v_cod_modulo;
               pr_ins_asi_manuales(r_bamde);

               -- Inserto el registro en la tabla cb_inf_der_gastos.
               pr_ins_der_gastos(v_fec_actual, v_cod_ofi_movimiento, v_cod_rubro, reg.cod_area, v_cod_modulo, v_cod_modalidad,
                                 reg.cod_tip_asientos, reg.cod_moneda,
                                 (CASE WHEN v_mto_mon_local < 0 THEN v_sal_mon_local * (-1) ELSE v_sal_mon_local END),
                                 reg.cod_tip_distribucion, v_cod_referencia);
            END IF;
         END LOOP;
      END IF;
      -- Actualizo el registro de gastos original.
      UPDATE cb_inf_der_gastos ci
         SET ci.cod_tip_distribucion = reg.cod_tip_distribucion,
             ci.referencia = v_cod_referencia
       WHERE ci.fecha = v_fec_actual
         AND ci.cod_rubro = reg.cod_rubro
         AND ci.cod_area = reg.cod_area
         AND ci.cod_oficina = reg.cod_oficina
         AND ci.cod_moneda = reg.cod_moneda;
   END LOOP;

   -- Realiza el ajuste contable.
   -- Fecha: 27/06/2016.
   -- Requerimiento: CNFDEEVO-46.
   -- Determinar cuales son los gastos que no estan detallados a nivel de centros de costos.
   v_cod_referencia := NVL(v_cod_referencia,0) + 1;
   FOR reg IN c_aju_contable LOOP
      -- Obtengo las oficinas del balance.
      FOR reg_1 IN (SELECT m.cod_rubro, m.cod_oficina FROM cb_sal_oficinas m WHERE m.cod_rubro = reg.cod_rubro) LOOP
         -- Obtiene el saldo estanco del balance y el saldo distribuido.
         v_sal_balance     := NVL(lf_obt_sal_balance(reg_1.cod_rubro,reg_1.cod_oficina),0);
         v_sal_distribuido := NVL(lf_obt_sal_distribuido(reg_1.cod_rubro,reg_1.cod_oficina),0);

         -- Verifico si existe diferencia.
         IF v_sal_balance <> v_sal_distribuido THEN
            pr_ins_der_gastos(v_fec_actual, reg_1.cod_oficina, reg_1.cod_rubro, v_cen_cos_generico, v_cod_modulo, v_cod_modalidad,
                              reg.cod_tip_asientos, v_cod_mon_local, (NVL(v_sal_balance,0) - NVL(v_sal_distribuido,0)), reg.cod_tip_distribucion, v_cod_referencia);
            -- Aumento el valor de la secuencia.
            v_cod_referencia := NVL(v_cod_referencia,0) + 1;
         END IF;
      END LOOP;
   END LOOP;

   -- Requerimiento: CNFAPDDG-3.
   -- Fecha: 26/05/2015.
   -- Realiza la reapertura del modulo de contabilidad.
   -- prb_reapertura;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'PR_PRO_DIS_GASTOS: '|| SQLERRM);
END;

-- Obtiene los asientos manuales registrados antes de ejecutar el proceso de distribuci�n.
-- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
PROCEDURE PR_GEN_ASI_MANUALES IS

   -- Variables.
   v_fec_actual    ge_movimientos.fecha%type      := pag_cal.fu_obt_fec_actual(2);
   v_cod_mon_local ge_movimientos.cod_moneda%type := pag_gen.fu_obt_mon_local;

   -- Cursores.
   CURSOR c_asi_manuales IS
      SELECT cd.fecha, cd.nro_cuenta, cd.cod_oficina, cd.cod_area,
             (CASE WHEN cs.tip_movimiento = 'D' THEN NVL(cs.mto_mon_local,0) ELSE NVL(cs.mto_mon_local,0) * -1 END) mto_mon_local,
             2 cod_modulo, 21 cod_modalidad, NULL cod_transaccion, cd.cod_rubro
        FROM cb_asientos ca, cb_asientos_det cs, cb_dat_asientos_det cd
       WHERE ca.fecha = cs.fecha
         AND ca.cod_oficina = cs.cod_oficina
         AND ca.nro_asiento = cs.nro_asiento
         AND cs.fecha = cd.fecha
         AND cs.cod_oficina = cd.cod_oficina
         AND cs.nro_asiento = cd.nro_asiento
         AND cs.nro_linea = cd.nro_linea
         AND substr(cs.cod_rubro,1,1) = '7'
         AND cd.cod_area IS NOT NULL;

BEGIN
   pag_cal.PR_OBT_DAT_CALENDAR(2);

   FOR reg IN c_asi_manuales LOOP
      -- Inserto en la tabla de derrama de gastos.
      BEGIN
         INSERT INTO cb_inf_der_gastos(fecha, cod_oficina, cod_rubro, cod_area, cod_modulo, cod_modalidad,
                                       cod_transaccion, cod_moneda, importe, cod_tip_distribucion, referencia,
                                      fec_proceso, hor_proceso)
              VALUES (pag_cal.g_ult_dia_mes_habil, reg.cod_oficina, reg.cod_rubro, reg.cod_area, reg.cod_modulo, reg.cod_modalidad,
                      reg.cod_transaccion, v_cod_mon_local, nvl(reg.mto_mon_local,0), null, null, v_fec_actual, null);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END LOOP;
END;

-- Obtiene los asientos manuales registrados antes de ejecutar el proceso de distribuci�n.
-- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
PROCEDURE PR_OBT_ASI_MANUALES IS
-- Variables.
v_fec_actual        ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(2);
BEGIN
   -- Obtiene la fecha del calendario.
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   --
   IF v_fec_actual <> pag_cal.g_ult_dia_mes_habil THEN
      pr_gen_asi_manuales;
   END IF;
END;

-- Movimientos de Apuntes Masivos.
-- Requerimiento: CNFDEEVO-46.
PROCEDURE PR_GEN_APU_MASIVOS IS
-- Variables.
   v_fec_actual    ge_movimientos.fecha%type      := pag_cal.fu_obt_fec_actual(1);
   v_cod_mon_local ge_movimientos.cod_moneda%type := pag_gen.fu_obt_mon_local;
   -- Cursores.
   CURSOR c_apu_masivos IS
      SELECT m.FECHA fec_pago,
             m.HORA,
             m.cod_oficina,
             REPLACE(d.cod_rubro,' ','') cod_rubro,
             m.nro_documento2 cod_area,
             m.cod_modulo,
             m.cod_modalidad,
             m.cod_transaccion,
             m.cod_moneda,
             (CASE WHEN d.tip_movimiento = 'D' THEN
                (CASE WHEN m.cod_moneda = v_cod_mon_local THEN NVL(m.monto,0) ELSE NVL(m.mto_equ_local,0) END)
              ELSE
                (CASE WHEN m.cod_moneda = v_cod_mon_local THEN NVL(m.monto,0) ELSE NVL(m.mto_equ_local,0) END) * -1
              END) importe
        FROM ge_movimientos m, cb_asi_automaticos_det d
       WHERE d.fecha                 = v_fec_actual
         AND SUBSTR(d.cod_rubro,1,1) = '7'
         AND d.fecha                 = m.fecha
         AND d.ref_movimiento        = m.nro_documento4
         AND m.COD_TRA_PADRE = 100
         AND m.cod_transaccion <> 100;

BEGIN
   -- Obtengo los valores del calendario.
   pag_cal.PR_OBT_DAT_CALENDAR(1);
   -- Inserto en la tabla de Derrama de Gastos.
   FOR reg IN c_apu_masivos LOOP
      -- Inserto en la tabla de derrama de gastos.
      BEGIN
         INSERT INTO cb_inf_der_gastos(fecha, cod_oficina, cod_rubro, cod_area, cod_modulo, cod_modalidad,
                                       cod_transaccion, cod_moneda, importe, cod_tip_distribucion, referencia,
                                       fec_proceso, hor_proceso)
              VALUES (pag_cal.g_ult_dia_mes_habil, reg.cod_oficina, reg.cod_rubro, reg.cod_area, reg.cod_modulo, reg.cod_modalidad,
                         reg.cod_transaccion, reg.cod_moneda, nvl(reg.importe,0), null, null, reg.fec_pago, reg.hora);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END LOOP;
   --
END;

END PAB_GTO;
/

