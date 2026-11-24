CREATE OR REPLACE PROCEDURE IT.PRA_CON_TRANSACCION (P_LUGAR IN VARCHAR2 DEFAULT 'C')
 IS
V_COD_MODULO GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MODALIDAD GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
V_COD_SUB_MODALIDAD AH_CTA_VISTAS.COD_SUB_MODALIDAD%TYPE;
V_FECHA GE_MOVIMIENTOS.FECHA%TYPE;
V_FEC_ANTERIOR GE_MOVIMIENTOS.FECHA%TYPE;
V_FEC_MOV GE_MOVIMIENTOS.FECHA%TYPE;
V_MODULO GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MAD_PADRE GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
V_COD_TRANSACCION GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_COD_MONEDA GE_MOVIMIENTOS.COD_MONEDA%TYPE;
V_COD_OFI_ORIGEN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE;
V_MOV_FILA VARCHAR2(100);
V_AFECTA GE_TRANSACCIONES.AFECTA%TYPE;
V_TRA_FILA VARCHAR2(100);
V_NOM_RUTINA1 VARCHAR2(1000);
V_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_HAY_ERROR VARCHAR2(1);
V_ERR_CLIENTE NUMBER(1);
V_RESIDENTE GE_TIP_DEUDORES.IND_RESIDENTE%TYPE;
V_COD_SECTOR GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE;
V_TIP_DEUDOR GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE;
V_COD_PLAZO GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
V_CAN_DIAS GE_PLZ_CONTABLES.CAN_DIAS%TYPE;
V_SIG_NRO_REFERENCIA NUMBER(10);
V_NRO_REFERENCIA NUMBER(10);
V_COD_OFICINA GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_MONTO GE_MOVIMIENTOS.MONTO%TYPE;
V_MTO_EQU_LOCAL GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE;
V_EST_CUENTA GE_MOVIMIENTOS.EST_CUENTA%TYPE;
V_FEC_VALOR GE_MOVIMIENTOS.FEC_VALOR%TYPE;
V_COD_TRA_PADRE GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE;
V_REVERSADO GE_MOVIMIENTOS.REVERSADO%TYPE;
V_EST_MOVIMIENTO GE_MOVIMIENTOS.ESTADO%TYPE;
V_COD_MOD_PADRE GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
v_cod_mon_local ba_monedas.cod_moneda%type;
v_nro_documento2 ge_movimientos.nro_documento2%type;
v_usu_insercion ge_movimientos.usu_insercion%type;
v_cod_sit_contable ge_movimientos.cod_sit_contable%type;
v_detallado varchar2(1);
v_cod_tip_referencia lc_ope_futuras.cod_tip_referencia%type;
V_NRO_REF_cambio GE_MOVIMIENTOS.NRO_DOCUMENTO2%TYPE;
V_NRO_CTA_AUX GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_NRO_SOLICITUD PR_SOLICITUDES.NRO_SOLICITUD%TYPE;
V_CTA_SEG_DISTR VARCHAR2(1);
v_mensaje varchar2(3000);
v_mensaje_ex varchar2(3000);
v_cant number(15);
v_cant_ant number(15);
v_can_movimiento NUMBER(15);
v_dia_lim        number := nvl(to_number(fug_obt_pardinamico('PRA_CON_TRA_DEL_FEC')),30); 
v_limit_lote     PLS_INTEGER := nvl(to_number(fug_obt_pardinamico('PRA_CON_TRA_LIMIT_LOTE')),50000); -- tamaño de lote del BULK COLLECT, ajustable sin recompilar
v_rows_del1      PLS_INTEGER := 0; -- diagnostico: filas eliminadas para corte historico
v_rows_del2      PLS_INTEGER := 0; -- diagnostico: filas eliminadas no procesadas del dia
v_rows_upd3      PLS_INTEGER := 0; -- diagnostico: filas update nro_documento4
v_del_job_name VARCHAR2(128); -- nombre del job asincrono de limpieza historica
v_del_fec      DATE; -- fecha tope para limpieza historica
-- Declaración de tipos y variables
TYPE t_con_fila_tab IS TABLE OF ROWID;  -- Para ROWID de GE_CON_TRANSACCIONES
TYPE t_cantidad_tab IS TABLE OF GE_CON_TRANSACCIONES.CANTIDAD%TYPE;
TYPE t_monto_tab IS TABLE OF GE_CON_TRANSACCIONES.TOTAL%TYPE;
TYPE t_mto_equ_local_tab IS TABLE OF GE_CON_TRANSACCIONES.TOT_MON_LOCAL%TYPE;

v_con_fila_tab t_con_fila_tab;
v_cantidad_tab t_cantidad_tab;
v_monto_tab t_monto_tab;
v_mto_equ_local_tab t_mto_equ_local_tab;


TYPE t_mov_fila_tab IS TABLE OF ROWID;  -- Para ROWID de GE_MOVIMIENTOS
TYPE t_nro_doc4_tab IS TABLE OF GE_MOVIMIENTOS.NRO_DOCUMENTO4%TYPE;
TYPE t_protegido_tab IS TABLE OF GE_MOVIMIENTOS.PROTEGIDO%TYPE;

v_mov_fila_tab t_mov_fila_tab;
v_nro_doc4_tab t_nro_doc4_tab;
v_protegido_tab t_protegido_tab;
--l_successful_rows t_mov_fila_tab;  -- Para guardar los registros exitosos

-- Declaración de tipos y variables
TYPE t_fecha_tab IS TABLE OF GE_CON_TRA_PROCESOS.FECHA%TYPE;
TYPE t_hora_tab IS TABLE OF GE_CON_TRA_PROCESOS.HORA%TYPE;
TYPE t_usuario_tab IS TABLE OF GE_CON_TRA_PROCESOS.COD_USUARIO%TYPE;
TYPE t_secuencia_tab IS TABLE OF GE_CON_TRA_PROCESOS.NRO_SECUENCIA%TYPE;
TYPE t_procesado_tab IS TABLE OF GE_CON_TRA_PROCESOS.PROCESADO%TYPE;
TYPE t_mensaje_tab IS TABLE OF GE_CON_TRA_PROCESOS.MENSAJE%TYPE;
TYPE t_reversado_tab IS TABLE OF GE_CON_TRA_PROCESOS.reversado%TYPE;
TYPE t_nro_referencia_tab IS TABLE OF GE_CON_TRA_PROCESOS.nro_referencia%TYPE;
TYPE t_monto_gp_tab IS TABLE OF GE_CON_TRA_PROCESOS.monto%TYPE;
TYPE t_mto_equ_local_gp_tab IS TABLE OF GE_CON_TRA_PROCESOS.mto_equ_local%TYPE;
v_fecha_tab t_fecha_tab;
v_hora_tab t_hora_tab;
v_usuario_tab t_usuario_tab;
v_secuencia_tab t_secuencia_tab;
v_procesado_tab t_procesado_tab;
v_mensaje_tab t_mensaje_tab;
v_reversado_tab t_reversado_tab;
v_nro_referencia_tab t_nro_referencia_tab;
v_monto_gp_tab t_monto_gp_tab;
v_mto_equ_local_gp_tab t_mto_equ_local_gp_tab;

--1. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_tra_datos IS RECORD (
   rutina1    ge_transacciones.rutina1%TYPE,
   tipo       ge_transacciones.tipo%TYPE,
   afecta     ge_transacciones.afecta%TYPE,
   detallado  ge_transacciones.detallado%TYPE,
   estado     VARCHAR2(15)
);

--2. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_tra_datos IS TABLE OF t_rec_tra_datos INDEX BY VARCHAR2(30);
v_col_tra_datos      t_tab_tra_datos;
v_idx_tab_tra_datos  VARCHAR2(30);

--1. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_cli_datos IS RECORD (
   residente         ge_clientes.residente%TYPE,
   cod_sec_contable  ge_clientes.cod_sec_contable%TYPE,
   cod_tip_deudor    ge_clientes.cod_tip_deudor%TYPE,
   estado            VARCHAR2(15)
);

--2. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_cli_datos IS TABLE OF t_rec_cli_datos INDEX BY VARCHAR2(30);
v_col_cli_datos      t_tab_cli_datos;
v_idx_tab_cli_datos  VARCHAR2(30);

--1. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_cta_datos IS RECORD (
   cod_sit_contable  ge_cuentas.cod_sit_contable%TYPE,
   estado            VARCHAR2(15)
);

--2. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_cta_datos IS TABLE OF t_rec_cta_datos INDEX BY VARCHAR2(30);
v_col_cta_datos      t_tab_cta_datos;
v_idx_tab_cta_datos  VARCHAR2(30);

--1. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_cat_datos IS RECORD (
   cat_automatica  ge_con_transacciones.cat_automatica%TYPE,
   estado          VARCHAR2(15)
);

--2. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_cat_datos IS TABLE OF t_rec_cat_datos INDEX BY VARCHAR2(30);
v_col_cat_datos      t_tab_cat_datos;
v_idx_tab_cat_datos  VARCHAR2(30);

--1. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_ah_datos IS RECORD (
   cod_sub_modalidad  ah_cta_vistas.cod_sub_modalidad%TYPE,
   estado             VARCHAR2(15)
);

--2. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_ah_datos IS TABLE OF t_rec_ah_datos INDEX BY VARCHAR2(30);
v_col_ah_datos      t_tab_ah_datos;
v_idx_tab_ah_datos  VARCHAR2(30);

--3. Tipo de registro para los datos que se van a recuperar
TYPE t_rec_tc_datos IS RECORD (
   tip_cuenta  ge_con_transacciones.tip_cuenta%TYPE,
   estado      VARCHAR2(15)
);

--4. Colección indexada por una clave que se pueda reconstruir y permita evitar repetir la query
TYPE t_tab_tc_datos IS TABLE OF t_rec_tc_datos INDEX BY VARCHAR2(30);
v_col_tc_datos      t_tab_tc_datos;
v_idx_tab_tc_datos  VARCHAR2(30);

-- Cache por nro_cuenta: CAN_DIAS es funcion pura de la cuenta (AH_CTA_PLAZOS/CERTIFICADOS)
TYPE t_tab_ah_plazo IS TABLE OF GE_PLZ_CONTABLES.CAN_DIAS%TYPE INDEX BY VARCHAR2(30);
v_col_ah_plazo_datos t_tab_ah_plazo;

-- Cache por nro_cuenta: estado contable de tarjeta es funcion pura de la cuenta (TA_CTA_TARJETAS)
TYPE t_tab_tarjeta_estado IS TABLE OF GE_MOVIMIENTOS.EST_CUENTA%TYPE INDEX BY VARCHAR2(30);
v_col_tarjeta_estado t_tab_tarjeta_estado;

-- Cache por nro_cuenta para PR_CTA_PRESTAMOS. estado_tabla es el valor CRUDO de la columna
-- (sin el NVL(v_est_cuenta,...) de entrada), que depende del movimiento y no se cachea.
TYPE t_rec_pr_prestamo IS RECORD (
   can_dias       GE_PLZ_CONTABLES.CAN_DIAS%TYPE,
   tip_cuenta     ge_con_transacciones.tip_cuenta%TYPE,
   tip_interes    ge_con_transacciones.tip_interes%TYPE,
   tip_renovacion ge_con_transacciones.tip_renovacion%TYPE,
   cod_sec_rubro  varchar2(3),
   estado_tabla   GE_MOVIMIENTOS.EST_CUENTA%TYPE
);
TYPE t_tab_pr_prestamo IS TABLE OF t_rec_pr_prestamo INDEX BY VARCHAR2(30);
v_col_pr_prestamo_datos t_tab_pr_prestamo;
v_prestamo_estado_tabla GE_MOVIMIENTOS.EST_CUENTA%TYPE;

-- Cache por nro_cuenta para MD_CTA_DOCUMENTOS, mismo criterio que PR_CTA_PRESTAMOS.
TYPE t_rec_md_documento IS RECORD (
   can_dias     GE_PLZ_CONTABLES.CAN_DIAS%TYPE,
   tip_interes  ge_con_transacciones.tip_interes%TYPE,
   estado_tabla GE_MOVIMIENTOS.EST_CUENTA%TYPE
);
TYPE t_tab_md_documento IS TABLE OF t_rec_md_documento INDEX BY VARCHAR2(30);
v_col_md_documento_datos t_tab_md_documento;
v_md_estado_tabla GE_MOVIMIENTOS.EST_CUENTA%TYPE;

-- Cache GE_CON_TRANSACCIONES evita SELECTs repetidos para la misma clave de consolidacion
-- clave por concatenacion (~120 chars), sin riesgo de overflow
TYPE t_rec_con_key IS RECORD (
   nro_referencia  GE_CON_TRANSACCIONES.NRO_REFERENCIA%TYPE,
   row_id          ROWID
);
TYPE t_tab_con_key IS TABLE OF t_rec_con_key INDEX BY VARCHAR2(200);
v_col_con_key  t_tab_con_key;
v_idx_con_key  VARCHAR2(200);

TYPE t_cotizacion_cache IS TABLE OF GE_COTIZACIONES.VAL_CONVERSION%TYPE INDEX BY VARCHAR2(10);
v_cotizacion_cache t_cotizacion_cache;

TYPE t_par_tra_cache IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(100);
v_par_tra_cache t_par_tra_cache;

v_rowcount     PLS_INTEGER := 0;
v_lote         PLS_INTEGER := 0;
v_cache_hits   PLS_INTEGER := 0; -- SELECTs evitados por cache GE_CON_TRANSACCIONES
v_mov      ge_movimientos%rowtype;


/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 );
v_tip_cuenta ge_con_transacciones.tip_cuenta%type;
v_tip_interes ge_con_transacciones.tip_interes%type;
v_tip_renovacion ge_con_transacciones.tip_renovacion%type;
v_cat_automatica ge_con_transacciones.cat_automatica%type;
v_concepto ge_con_transacciones.concepto%type;
v_cod_persona ge_movimientos.cod_persona%type;
v_cod_usuario ge_movimientos.cod_usuario%type;
v_hora        ge_movimientos.hora%type;
v_referencia  ge_movimientos.referencia%type;
--v_nro_doc_persona varchar2(30);
--v_nom_completo    varchar2(300);
v_cod_rubro       varchar2(20);
v_nro_secuencia   number;
v_nro_registros   number := 0;
v_cod_sec_rubro   varchar2(3); -- dato para contabilizar los prestamos por sector de credito, para el resto es null

v_cod_tra_pre_tar ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_TRA_PRE_TARJETAS');

CURSOR CURSOR1 IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, nvl(MONTO,0) as monto,
          EST_CUENTA, FEC_VALOR, COD_TRA_PADRE, REVERSADO, ESTADO,
          COD_MOD_PADRE, COD_MAD_PADRE, COD_TRANSACCION, COD_MONEDA, COD_OFI_ORIGEN,
          MTO_EQU_LOCAL, NRO_DOCUMENTO2, USU_INSERCION, rowid,
          COD_SIT_CONTABLE, CONCEPTO,
          COD_PERSONA, cod_ref_cambio,
          cod_usuario, hora, referencia, nro_secuencia,
          cod_rubro, FECHA,
          cod_tip_ope_cambio, nro_documento, tip_mov_rubro, nro_documento3
     FROM GE_MOVIMIENTOS g
    WHERE /*COD_MODULO IN (1,2,3,4,5,6,7,8,9,10,13,14,15,16,26,28,30,31) AND*/ COD_TRANSACCION > 0
      AND ESTADO = 'N'
      AND G.FECHA >= V_FECHA  --index range scan via IN_GEMOV_COD_MOD_PADRE + reduce hash build del NOT EXISTS
      AND ( p_lugar = 'C' OR cod_mod_padre <> 7 )
      AND ( p_lugar = 'C' OR cod_moneda = v_cod_mon_local )
      AND not exists (select 1
                      from it.GE_CON_TRA_PROCESOS a
                      where g.fecha = a.fecha
                      and   g.hora = a.hora
                      and   g.nro_secuencia = a.nro_secuencia
                      and   g.cod_usuario   = a.cod_usuario
                      and   a.procesado = 'S'
                      and   a.fecha >= V_FECHA);  --evita cargar histórico de GE_CON_TRA_PROCESOS en el hash
TYPE cursor1_type IS TABLE OF cursor1%ROWTYPE;
reg_movimientos cursor1_type;

--Genera clave para cache en-memoria. Concatenacion nativa PL/SQL (evita context switch de JSON_ARRAY)
FUNCTION FU_GEN_KEY_CACHE(
   p_fecha            IN DATE,
   p_cod_mod_padre    IN NUMBER,
   p_cod_mad_padre    IN NUMBER,
   p_cod_ofi_origen   IN NUMBER,
   p_cod_oficina      IN NUMBER,
   p_cod_moneda       IN VARCHAR2,
   p_cod_modulo       IN NUMBER,
   p_cod_modalidad    IN NUMBER,
   p_cod_transaccion  IN NUMBER,
   p_cod_sector       IN VARCHAR2,
   p_tip_deudor       IN NUMBER,
   p_residente        IN VARCHAR2,
   p_cod_plazo        IN NUMBER,
   p_reversado        IN VARCHAR2,
   p_est_cuenta       IN VARCHAR2,
   p_tip_cuenta       IN VARCHAR2,
   p_tip_interes      IN VARCHAR2,
   p_tip_renovacion   IN VARCHAR2,
   p_cat_automatica   IN NUMBER,
   p_cod_sit_contable IN NUMBER,
   p_cod_sec_rubro    IN VARCHAR2
) RETURN VARCHAR2 IS
BEGIN
   -- Clave canónica: evita ambiguedad por NULL/formatos NLS en concatenaciones implícitas.
   RETURN NVL(TO_CHAR(p_fecha,'YYYYMMDD'),'#')||'|'||
      NVL(TO_CHAR(p_cod_mod_padre,'TM'),'#')||'|'||
      NVL(TO_CHAR(p_cod_mad_padre,'TM'),'#')||'|'||
      NVL(TO_CHAR(p_cod_ofi_origen,'TM'),'#')||'|'||
      NVL(TO_CHAR(p_cod_oficina,'TM'),'#')||'|'||
      NVL(TRIM(p_cod_moneda),'#')||'|'||
      NVL(TO_CHAR(p_cod_modulo,'TM'),'#')||'|'||
      NVL(TO_CHAR(p_cod_modalidad,'TM'),'#')||'|'||
      NVL(TO_CHAR(p_cod_transaccion,'TM'),'#')||'|'||
      NVL(TRIM(p_cod_sector),'#')||'|'||
      NVL(TO_CHAR(p_tip_deudor,'TM'),'#')||'|'||
      NVL(TRIM(p_residente),'#')||'|'||
      NVL(TO_CHAR(p_cod_plazo,'TM'),'#')||'|'||
      NVL(TRIM(p_reversado),'#')||'|'||
      NVL(TRIM(p_est_cuenta),'X')||'|'||
      NVL(TRIM(p_tip_cuenta),'X')||'|'||
      NVL(TRIM(p_tip_interes),'X')||'|'||
      NVL(TRIM(p_tip_renovacion),'X')||'|'||
      NVL(TO_CHAR(p_cat_automatica,'TM'),'9')||'|'||
      NVL(TO_CHAR(p_cod_sit_contable,'TM'),'-1')||'|'||
      NVL(TRIM(p_cod_sec_rubro),'N');
END FU_GEN_KEY_CACHE;

/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 )
 IS
BEGIN
  SELECT COD_PLAZO
    INTO p_cod_plazo
    FROM GE_PLZ_CONTABLES
   WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                       FROM GE_PLZ_CONTABLES
                      WHERE CAN_DIAS >= p_can_dias);
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'En lp_obt_cod_plazo '||SQLERRM);
END;
/* Procedimiento Equivalente Moneda Local */
PROCEDURE LP_EQU_MON_LOCAL
 IS

V_MTO_COTIZACION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
V_COD_MONEDA BA_MONEDAS.COD_MONEDA%TYPE;
CURSOR c_movimientos IS
   SELECT DISTINCT COD_MONEDA
     FROM GE_MOVIMIENTOS
    WHERE COD_MONEDA <> v_cod_mon_local
      AND MTO_EQU_LOCAL IS NULL;


BEGIN

   OPEN c_movimientos;
   LOOP
      FETCH c_movimientos INTO v_cod_moneda;
         EXIT WHEN c_movimientos%NOTFOUND;
         ---------------------------------------------------------
         -----      LEER COTIZACION
         ---------------------------------------------------------
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fecha);
         ----------------------------------------------------------
         -------- ACTUALIZA GE_MOVIMIENTOS CON EL IMPORTE EQUIVALENTE GS.
         ----------------------------------------------------------
         UPDATE GE_MOVIMIENTOS
            SET MTO_EQU_LOCAL = round(nvl(MONTO,0)*v_mto_cotizacion,0),
                COTIZACION = v_mto_cotizacion
          WHERE COD_MONEDA = v_cod_moneda
            AND   MTO_EQU_LOCAL IS NULL;
   END LOOP;
   IF c_movimientos%ISOPEN THEN
      CLOSE c_movimientos;
   END IF;
END;

FUNCTION LF_OBT_COTIZACION(
   p_cod_moneda IN BA_MONEDAS.COD_MONEDA%TYPE
) RETURN GE_COTIZACIONES.VAL_CONVERSION%TYPE
IS
   v_key BA_MONEDAS.COD_MONEDA%TYPE;
BEGIN
   v_key := TRIM(p_cod_moneda);
   IF NOT v_cotizacion_cache.EXISTS(v_key) THEN
      v_cotizacion_cache(v_key) := pag_gen.fu_obt_cotizacion(v_key, v_fecha);
   END IF;
   RETURN v_cotizacion_cache(v_key);
END;

FUNCTION LF_OBT_PAR_TRA_SEG_VIDA(
   p_cod_tra_padre IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
   p_cod_mod_padre IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE,
   p_cod_mad_padre IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
) RETURN VARCHAR2
IS
   v_key VARCHAR2(100);
BEGIN
   v_key := NVL(TO_CHAR(p_cod_tra_padre),'#')||'|'||NVL(TO_CHAR(p_cod_mod_padre),'#')||'|'||NVL(TO_CHAR(p_cod_mad_padre),'#');
   IF NOT v_par_tra_cache.EXISTS(v_key) THEN
      v_par_tra_cache(v_key) := fug_obt_par_transacciones(
         p_cod_tra_padre,
         p_cod_mod_padre,
         p_cod_mad_padre,
         'COD_TRA_DIS_SEG_VIDA'
      );
   END IF;
   RETURN v_par_tra_cache(v_key);
END;

FUNCTION LF_OBT_REFERENCIA (
   p_mov ge_movimientos%rowtype
) RETURN VARCHAR2 IS
   v_concepto          ge_con_transacciones.concepto%TYPE :=null;
   v_gmov              ge_movimientos%rowtype;
   v_afe_transferencia VARCHAR2(1);
   v_afe_libranza      VARCHAR2(1);
   v_id_sesion         ge_spi_transferencias.id_sesion%TYPE;
   BEGIN
   v_gmov := p_mov;
  --
   IF
      v_gmov.cod_mod_padre = 7
      AND v_gmov.nro_secuencia IN ( 1, 2 )
      AND v_gmov.cod_tip_ope_cambio IS NOT NULL
   THEN
      BEGIN
         SELECT
            nvl(afe_transferencia, 'N'),
            nvl(afe_libranza, 'N')
         INTO
            v_afe_transferencia,
            v_afe_libranza
         FROM
            lc_tip_operaciones
         WHERE
            cod_tip_operacion = v_gmov.cod_tip_ope_cambio;

      EXCEPTION
         WHEN OTHERS THEN
            v_afe_transferencia := 'N';
            v_afe_libranza := 'N';
      END;

   END IF;
  --
   IF
      v_gmov.cod_modalidad = 72
      AND v_gmov.cod_transaccion = 785
   THEN
    -- detalle especial de transacciones de desglose de comisiones por operaciones de cmbios
      v_concepto := substr('/011/'
                           || lpad(nvl(v_gmov.cod_persona, '999999'), 6, '0')
                           || '/'
                           || fue_obt_nom_persona(v_gmov.cod_persona), 1, 100);
   ELSIF
      v_gmov.cod_mod_padre = 7
      AND ( nvl(v_afe_transferencia, 'N') = 'S' OR nvl(v_afe_libranza, 'N') = 'S' )
   THEN
    -- compra de transferencias o venta de transferencias
      BEGIN
         SELECT
            substr('//'
                   || nro_ref_externa
                   || '//'
                   || nom_beneficiario, 1, 100)
         INTO v_concepto
         FROM
            lc_transferencias x
         WHERE
            ( x.nro_operacion = v_gmov.nro_documento
              AND v_afe_transferencia = 'S' )
            OR ( x.cod_tip_referencia = v_gmov.cod_ref_cambio
                 AND x.nro_referencia = v_gmov.nro_documento2
                 AND v_afe_libranza = 'S' );

      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

   ELSIF
      v_gmov.cod_mod_padre = 7
      AND v_gmov.cod_transaccion IN ( 842, 741 )
      AND v_gmov.cod_rubro IN ( 240402600288810, 240402600288814, 240402600288807, 240402600288803, 240402600288805,
                                240402600288817, 240402600288899, 240402600288828 )
      AND v_gmov.concepto LIKE '%Cambios%'
   THEN
      v_concepto := '/CAMBIOS/' || v_gmov.cod_persona;
   ELSIF
      v_gmov.cod_mod_padre = 7
      AND v_gmov.cod_transaccion IN ( 842, 741 )
      AND v_gmov.cod_rubro IN ( 240402600288810, 240402600288814, 240402600288807, 240402600288803, 240402600288805,
                                240402600288817, 240402600288899, 240402600288828 )
      AND v_gmov.reversado = 'S'
      AND v_gmov.monto < 0
   THEN
      v_concepto := '/CAMBIOS/' || v_gmov.cod_persona;
   ELSIF
      v_gmov.cod_mod_padre = 4
      AND v_gmov.cod_mad_padre = 41
      AND v_gmov.cod_tra_padre = 227
      AND v_gmov.cod_moneda = 'GS'
      AND v_gmov.cod_transaccion = 503
   THEN
      v_concepto := v_gmov.nro_documento3
                    || ' '
                    || v_gmov.concepto;
   ELSE

    --para obtener el concepto originar de los prestamos automaticos
      IF v_gmov.cod_transaccion IN ( 5503, 6602 ) THEN
         v_concepto := v_gmov.concepto;
      ELSIF v_gmov.cod_transaccion IN ( 3602, 3503, 8503 ) THEN
         SELECT
            decode(substr(v_gmov.concepto, 0, 4),
                   'BAJA',
                   substr(v_gmov.concepto,
                          instr(v_gmov.concepto, '/'),
                          30),
                   v_gmov.concepto)
         INTO v_concepto
         FROM
            dual;

      ELSE
         IF
            v_gmov.cod_moneda = 'USD'
            AND v_gmov.concepto = 'HSBC'
         THEN
            BEGIN
               SELECT
                  observacion
               INTO v_concepto
               FROM
                  lc_ope_pendientes z
               WHERE
                  z.nro_operacion = v_gmov.nro_documento;

               v_concepto := v_gmov.concepto
                             || '-'
                             || v_concepto;
            EXCEPTION
               WHEN OTHERS THEN
                  v_concepto := NULL;
            END;

         END IF;
      END IF;
   END IF;

  --BSEVOCORE-1063 SPI - Visualizar ID. de Mensaje (concepto del movimiento)
   IF
      v_gmov.cod_tra_padre = 303
      AND v_gmov.cod_transaccion IN ( 247, 248 )
   THEN
      BEGIN
         SELECT
            a.id_sesion
         INTO v_id_sesion
         FROM
            ge_spi_transferencias a
         WHERE
            a.nro_referencia = v_gmov.nro_documento;

      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      v_concepto := v_gmov.concepto
                    || '-'
                    || v_id_sesion;
      v_concepto := substr(v_concepto, 1, 60);
   END IF;

   RETURN v_concepto;
end LF_OBT_REFERENCIA;

 PROCEDURE LP_REPROCESAR_REV IS
    TYPE r_reversion IS RECORD (
        nro_documento4   ge_movimientos.nro_documento4%TYPE,
        monto            ge_con_tra_procesos.monto%TYPE,
        mto_equ_local    ge_con_tra_procesos.mto_equ_local%TYPE,
        fecha            ge_con_tra_procesos.fecha%TYPE,
        hora             ge_con_tra_procesos.hora%TYPE,
        cod_usuario      ge_con_tra_procesos.cod_usuario%TYPE,
        nro_secuencia    ge_con_tra_procesos.nro_secuencia%TYPE
    );

    TYPE t_reversion IS TABLE OF r_reversion;
    l_reversiones t_reversion;
    v_cant_mov NUMBER(10);
    CURSOR v_rev IS
        SELECT
            g.nro_documento4,
            NVL(p.monto, 0) AS monto,
            NVL(p.mto_equ_local, 0) AS mto_equ_local,
            p.fecha,
            p.hora,
            p.cod_usuario,
            p.nro_secuencia
        FROM ge_con_tra_procesos p,
            ge_movimientos g
        WHERE   g.fecha = p.fecha
            AND g.hora = p.hora
            AND g.cod_usuario = p.cod_usuario
            AND g.nro_secuencia = p.nro_secuencia
            AND p.procesado = 'S'
            AND p.reversado = 'N'
            AND g.reversado = 'S';

BEGIN
    
    OPEN v_rev;
    FETCH v_rev BULK COLLECT INTO l_reversiones;
    CLOSE v_rev;

    IF l_reversiones.COUNT > 0 THEN
        FOR i IN 1..l_reversiones.COUNT LOOP
            BEGIN
                SELECT c.cantidad
                INTO v_cant_mov /*La cantidad de registros asociados al numero de referencia*/
                FROM ge_con_transacciones c
                WHERE c.fecha = l_reversiones(i).fecha
                  AND c.nro_referencia = l_reversiones(i).nro_documento4;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_cant_mov := 0;
            END;
            /*Si la cantidad es 1 registro, elimina para volver a reprocesar*/
            IF v_cant_mov = 1 THEN
                DELETE ge_con_transacciones c
                WHERE c.nro_referencia = l_reversiones(i).nro_documento4
                AND   c.fecha = l_reversiones(i).fecha;
            ELSE /*Si es mayor a 1, resta la cantidad y montos asociados al numero de referencia*/
                UPDATE ge_con_transacciones c
                SET   c.cantidad = c.cantidad - 1,
                      c.total = c.total - l_reversiones(i).monto,
                      c.tot_mon_local = c.tot_mon_local - l_reversiones(i).mto_equ_local
                WHERE c.nro_referencia = l_reversiones(i).nro_documento4
                AND   c.fecha = l_reversiones(i).fecha;
            END IF;
            /*Eliminamos de la tabla ge_con_tra_procesos el registro a reprocesar*/
            BEGIN
                DELETE ge_con_tra_procesos c
                WHERE   c.fecha = l_reversiones(i).fecha
                    AND c.hora = l_reversiones(i).hora
                    AND c.cod_usuario = l_reversiones(i).cod_usuario
                    AND c.nro_secuencia = l_reversiones(i).nro_secuencia;
            END;
            /*Vaciamos el campo nro_documento4 que esta asociado con el nro_referencia para su reproceso*/
            BEGIN
                UPDATE ge_movimientos c
                SET     c.nro_documento4 = NULL
                WHERE   c.fecha = l_reversiones(i).fecha
                    AND c.hora = l_reversiones(i).hora
                    AND c.cod_usuario = l_reversiones(i).cod_usuario
                    AND c.nro_secuencia = l_reversiones(i).nro_secuencia;
            END;
        END LOOP;
        COMMIT;
    END IF;

END LP_REPROCESAR_REV;

---Proceso que re-consolida movimientos que fueron modficados --RZ2026
PROCEDURE LP_ACT_CONSOLIDADO IS
    TYPE r_mod_mov IS RECORD (
        nro_referencia   ge_movimientos.nro_documento4%TYPE,
        monto            ge_con_tra_procesos.monto%TYPE,
        mto_equ_local    ge_con_tra_procesos.mto_equ_local%TYPE,
        fecha            ge_con_tra_procesos.fecha%TYPE,
        hora             ge_con_tra_procesos.hora%TYPE,
        cod_usuario      ge_con_tra_procesos.cod_usuario%TYPE,
        nro_secuencia    ge_con_tra_procesos.nro_secuencia%TYPE
    );

    TYPE t_mod_mov  IS TABLE OF r_mod_mov;
    l_mod_mov  t_mod_mov ;
    v_cant_mov NUMBER(10);
    CURSOR v_rev IS
       SELECT p.nro_referencia,
               NVL(p.monto, 0) AS monto,
               NVL(p.mto_equ_local, 0) AS mto_equ_local,
               p.fecha,
               p.hora,
               p.cod_usuario,
               p.nro_secuencia
      FROM ge_con_tra_procesos p
      WHERE p.fecha >= v_fecha
      AND p.procesado = 'S'
      AND NOT EXISTS (select * 
                      from ge_movimientos g 
                      WHERE g.fecha = p.fecha
                      AND g.hora = p.hora
                      AND g.cod_usuario = p.cod_usuario
                      AND g.nro_secuencia = p.nro_secuencia
                      AND g.nro_documento4 = P.NRO_REFERENCIA);

BEGIN
    
    OPEN v_rev;
    FETCH v_rev BULK COLLECT INTO l_mod_mov ;
    CLOSE v_rev;

    IF l_mod_mov.COUNT > 0 THEN
        FOR i IN 1..l_mod_mov.COUNT LOOP
            BEGIN
                SELECT c.cantidad
                INTO v_cant_mov /*La cantidad de registros asociados al numero de referencia*/
                FROM ge_con_transacciones c
                WHERE c.fecha = v_fecha 
                  AND c.fecha <= l_mod_mov(i).fecha
                  AND c.nro_referencia = l_mod_mov(i).nro_referencia;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_cant_mov := 0;
            END;
            /*Si la cantidad es 1 registro, elimina para volver a reprocesar*/
            IF v_cant_mov = 1 THEN
                DELETE ge_con_transacciones c
                WHERE c.nro_referencia = l_mod_mov(i).nro_referencia
                  AND c.fecha = v_fecha 
                  AND c.fecha <= l_mod_mov(i).fecha;
            ELSIF v_cant_mov > 1 THEN /*Si es mayor a 1, resta la cantidad y montos asociados al numero de referencia*/
                UPDATE ge_con_transacciones c
                SET   c.cantidad = c.cantidad - 1,
                      c.total = c.total - l_mod_mov(i).monto,
                      c.tot_mon_local = c.tot_mon_local - l_mod_mov(i).mto_equ_local
                WHERE c.nro_referencia = l_mod_mov(i).nro_referencia
                  AND c.fecha = v_fecha 
                  AND c.fecha <= l_mod_mov(i).fecha;
            END IF;
            /*Eliminamos de la tabla ge_con_tra_procesos el registro a reprocesar*/
            BEGIN
                DELETE ge_con_tra_procesos c
                WHERE   c.fecha = l_mod_mov(i).fecha
                    AND c.hora = l_mod_mov(i).hora
                    AND c.cod_usuario = l_mod_mov(i).cod_usuario
                    AND c.nro_secuencia = l_mod_mov(i).nro_secuencia;
            END;
        END LOOP;
        COMMIT;
    END IF;

END LP_ACT_CONSOLIDADO;

BEGIN
it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', '0 Inicio...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   -- Registrar el nombre en action
   DBMS_APPLICATION_INFO.SET_ACTION('PRA_CON_TRANSACCION');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRA_CON_TRANSACCION, Iniciando');

   v_err_cliente := 0;
   v_modulo      := 3; -- Modulo de Ahorro
   v_fecha       := pag_cal.FU_OBT_FEC_ACTUAL(v_modulo);
   v_fec_anterior:= pag_cal.FU_OBT_FEC_ANTERIOR(v_modulo);
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;

   -- Limpiar las colecciones
   v_con_fila_tab := t_con_fila_tab();
   v_cantidad_tab := t_cantidad_tab();
   v_monto_tab := t_monto_tab();
   v_mto_equ_local_tab := t_mto_equ_local_tab();

   v_mov_fila_tab := t_mov_fila_tab();
   v_nro_doc4_tab := t_nro_doc4_tab();
   v_protegido_tab := t_protegido_tab();

    v_fecha_tab     := t_fecha_tab();
    v_hora_tab      :=t_hora_tab();
    v_usuario_tab   :=t_usuario_tab();
    v_secuencia_tab :=t_secuencia_tab();
    v_procesado_tab := t_procesado_tab();
    v_mensaje_tab   := t_mensaje_tab();
    v_reversado_tab   := t_reversado_tab();
    v_nro_referencia_tab   := t_nro_referencia_tab();
    v_monto_gp_tab   := t_monto_gp_tab();
    v_mto_equ_local_gp_tab   := t_mto_equ_local_gp_tab();

    -- Solo se necesita el total real de movimientos para el log de avance
    SELECT COUNT(1)
       INTO v_can_movimiento
     FROM GE_MOVIMIENTOS
    WHERE COD_TRANSACCION > 0
      AND ESTADO = 'N';
    
    it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'LP_REPROCESAR_REV...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
    LP_REPROCESAR_REV;
    it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'Post LP_REPROCESAR_REV / pre LP_ACT_CONSOLIDADO...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
    LP_ACT_CONSOLIDADO;
    it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'post COUNT...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

      IF P_LUGAR = 'C' THEN
         -- En cierre central, la limpieza historica se difiere a job para no frenar el pre-loop.
         it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'delete historico de ge_con_tra_procesos diferido a job (modo C)', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      ELSE
         DELETE FROM GE_CON_TRA_PROCESOS
          WHERE FECHA <= V_FEC_ANTERIOR - v_dia_lim;
         v_rows_del1 := SQL%ROWCOUNT;
         COMMIT;
         it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'post delete '||v_dia_lim||' dias atras rows='||v_rows_del1, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      END IF;

      /*Eliminamos los registros no procesados del dia para volver a procesarlos.*/
      DELETE FROM GE_CON_TRA_PROCESOS
       WHERE FECHA = V_FECHA
          AND PROCESADO = 'N';
      v_rows_del2 := SQL%ROWCOUNT;
      COMMIT;
      it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', '2b post delete dia actual rows='||v_rows_del2, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
    
    /*Vaciamos el campo nro_documento4 para los registros pendientes a procesar*/
    BEGIN
        UPDATE GE_MOVIMIENTOS g
        SET G.NRO_DOCUMENTO4 = NULL
          WHERE G.NRO_DOCUMENTO4 IS NOT NULL
            AND G.FECHA >= V_FECHA
            AND not exists (select 1
                            from it.GE_CON_TRA_PROCESOS a
                            where g.fecha = a.fecha
                            and   g.hora = a.hora
                            and   g.nro_secuencia = a.nro_secuencia
                            and   g.cod_usuario   = a.cod_usuario
                            and   a.procesado = 'S'
                            and   a.fecha >= v_fecha);    --evita cargar histórico de GE_CON_TRA_PROCESOS en el hash
                            v_rows_upd3 := SQL%ROWCOUNT;
                            commit;
    END;
    it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'post update nro_documento4 total de filas '||v_rows_upd3, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   ---2. Leo el sgte. nro. de referencia del GE_PAR_GENERALES ---------------
   v_sig_nro_referencia := fug_obt_pardinamico('SIG_NRO_REFERENCIA',v_cod_modulo, v_cod_modalidad, v_cod_oficina,v_cod_moneda);
   it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', '3 cursor1%ISOPEN...', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   ---3. Leyendo los datos del diario (GE_MOVIMIENTOS) y act.GE_CON_TRANSACCIONES-------
   IF cursor1%ISOPEN THEN
      CLOSE cursor1;
   END IF;
   OPEN cursor1;
   LOOP
    FETCH cursor1 BULK COLLECT
     INTO reg_movimientos LIMIT v_limit_lote ;

      EXIT WHEN reg_movimientos.COUNT = 0;

    v_rowcount := v_rowcount + reg_movimientos.count;
    v_lote    := v_lote + 1;

    FOR i IN 1 .. reg_movimientos.count LOOP
      v_cod_sec_rubro := 'N'; -- dato por defecto
      --- leo el registro del GE_MOVIMIENTOS --------------------------------
      v_cod_modulo        := reg_movimientos(i).cod_modulo;
      v_cod_modalidad     := reg_movimientos(i).cod_modalidad;
      v_cod_oficina       := reg_movimientos(i).cod_oficina;
      v_nro_cuenta        := reg_movimientos(i).nro_cuenta;
      v_monto             := reg_movimientos(i).monto;
      v_est_cuenta        := reg_movimientos(i).est_cuenta;
      v_fec_valor         := reg_movimientos(i).fec_valor;
      v_cod_tra_padre     := reg_movimientos(i).cod_tra_padre;
      v_reversado         := reg_movimientos(i).reversado;
      v_est_movimiento    := reg_movimientos(i).estado;
      v_cod_mod_padre     := reg_movimientos(i).cod_mod_padre;
      v_cod_mad_padre     := reg_movimientos(i).cod_mad_padre;
      v_cod_transaccion   := reg_movimientos(i).cod_transaccion;
      v_cod_moneda        := reg_movimientos(i).cod_moneda;
      v_cod_ofi_origen    := reg_movimientos(i).cod_ofi_origen;
      v_mto_equ_local     := reg_movimientos(i).mto_equ_local;
      v_nro_documento2    := reg_movimientos(i).nro_documento2;
      v_usu_insercion     := reg_movimientos(i).usu_insercion;
      v_mov_fila          := reg_movimientos(i).rowid;
      v_cod_sit_contable  := reg_movimientos(i).cod_sit_contable;
      v_concepto          := reg_movimientos(i).concepto;
      v_cod_persona       := reg_movimientos(i).cod_persona;
      v_cod_tip_referencia:= reg_movimientos(i).cod_ref_cambio;
      v_nro_ref_cambio    := reg_movimientos(i).nro_documento2;
      v_cod_usuario       := reg_movimientos(i).cod_usuario;
      v_hora              := reg_movimientos(i).hora;
      v_referencia        := reg_movimientos(i).referencia;
      v_nro_secuencia     := reg_movimientos(i).nro_secuencia;
      v_cod_rubro         := reg_movimientos(i).cod_rubro;
      v_fec_mov           := reg_movimientos(i).fecha;
      v_nro_registros := v_nro_registros + 1;
      --- asigno valores por defecto, por si exista cuenta cliente ---
      v_residente  := 'S';
      v_cod_sector := 'N';
      v_tip_deudor := '2';
      v_cod_plazo  := 0;
      v_tip_cuenta := NULL;
      --v_est_cuenta := null;
      v_tip_interes := null;
      v_tip_renovacion := null;
      v_cat_automatica := null;
      v_can_dias := null;
      V_CTA_SEG_DISTR := 'N';
      v_idx_con_key := NULL;
      --- Comun a todos los modulos-----------------------------------
      v_hay_error  := 'N';
      v_mensaje := null;

      --3. Construir clave para la colección indexada
      v_idx_tab_tra_datos := v_cod_transaccion||'_'||v_cod_modulo||'_'||v_cod_modalidad;

      --3.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
      IF v_col_tra_datos.EXISTS(v_idx_tab_tra_datos) THEN
         IF v_col_tra_datos(v_idx_tab_tra_datos).estado = 'OK' THEN
            v_nom_rutina1 := v_col_tra_datos(v_idx_tab_tra_datos).rutina1;
            v_detalle     := v_col_tra_datos(v_idx_tab_tra_datos).tipo;
            v_afecta      := v_col_tra_datos(v_idx_tab_tra_datos).afecta;
            v_detallado   := v_col_tra_datos(v_idx_tab_tra_datos).detallado;
         ELSIF v_col_tra_datos(v_idx_tab_tra_datos).estado = 'NO_DATA_FOUND' THEN
            /* v_hay_error := 'S';
            raise_application_error(-20000,'Trans. no existe '||to_char(v_cod_modulo)||' '
                                    ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion));*/
            v_mensaje := 'Trans. no existe '||to_char(v_cod_modulo)||' '
                                    ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion);
            v_hay_error := 'S';
            UPDATE GE_MOVIMIENTOS
            SET    ESTADO = 'E'
            WHERE rowid = v_mov_fila;
         ELSE
            v_mensaje := 'Error al obtener datos de la transaccion '||to_char(v_cod_modulo)||' '
                                    ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion);
            v_hay_error := 'S';
         END IF;

      --3.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
      ELSE
         BEGIN
             SELECT upper(rtrim(RUTINA1)),
                    TIPO, AFECTA, nvl(detallado,'N')
               INTO v_nom_rutina1, v_detalle, v_afecta, v_detallado
               FROM GE_TRANSACCIONES
              WHERE COD_TRANSACCION = v_cod_transaccion
                AND COD_MODULO = v_cod_modulo
                AND COD_MODALIDAD = v_cod_modalidad;

             --3.2.a Se guardan los datos
             v_col_tra_datos(v_idx_tab_tra_datos).rutina1   := v_nom_rutina1;
             v_col_tra_datos(v_idx_tab_tra_datos).tipo      := v_detalle;
             v_col_tra_datos(v_idx_tab_tra_datos).afecta    := v_afecta;
             v_col_tra_datos(v_idx_tab_tra_datos).detallado := v_detallado;
             v_col_tra_datos(v_idx_tab_tra_datos).estado    := 'OK';
         EXCEPTION
             WHEN NO_DATA_FOUND THEN
               /* v_hay_error := 'S';
              raise_application_error(-20000,'Trans. no existe '||to_char(v_cod_modulo)||' '
                                       ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion));*/
              v_mensaje := 'Trans. no existe '||to_char(v_cod_modulo)||' '
                                       ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion);
              v_hay_error := 'S';
              UPDATE GE_MOVIMIENTOS
              SET    ESTADO = 'E'
              WHERE rowid = v_mov_fila;

               --3.2.b Se guarda el estado
               v_col_tra_datos(v_idx_tab_tra_datos).estado := 'NO_DATA_FOUND';
         END;
      END IF;

      if v_cod_rubro is not null then
         v_detallado := 'S'; -- siempre que haya rubro en el movimiento debe si o si ser detallado
      end if;
      v_err_cliente := 0;
      IF v_hay_error = 'N' THEN
         --- busco el cliente principal de la cuenta ------------------
          IF v_cod_modulo = 7 and v_nro_ref_cambio is not null and v_nro_cuenta is null then
             BEGIN
             SELECT FEC_VENCIMIENTO - FEC_OPERACION
                INTO v_can_dias
              FROM LC_OPE_FUTURAS
             WHERE cod_tip_referencia = v_cod_tip_referencia
               and nro_referencia = v_nro_ref_cambio;
               lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
             EXCEPTION
                WHEN no_data_found then
                   null;
               END;
            IF v_cod_persona is not null then
            -- el movimiento tiene persona identificada, se puede buscar los datos del cliente
              BEGIN
                SELECT GE_CLIENTES.RESIDENTE,GE_CLIENTES.COD_SEC_CONTABLE,
                GE_CLIENTES.COD_TIP_DEUDOR
                  INTO v_residente, v_cod_sector, v_tip_deudor
                  FROM GE_CLIENTES
                 WHERE GE_CLIENTES.COD_PERSONA = v_cod_persona;
              EXCEPTION
                 WHEN OTHERS THEN
                      v_residente  := 'S';
                      v_cod_sector := 'N';
                      v_tip_deudor := '2';
              END;
            END IF;
         ELSIF v_nro_cuenta IS NOT NULL THEN
            --3. Construir clave para la colección indexada
            v_idx_tab_cli_datos := v_nro_cuenta||'_'||v_cod_modulo||'_'||v_cod_modalidad;

            --3.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
            IF v_col_cli_datos.EXISTS(v_idx_tab_cli_datos) THEN
               IF v_col_cli_datos(v_idx_tab_cli_datos).estado = 'OK' THEN
                  v_residente  := v_col_cli_datos(v_idx_tab_cli_datos).residente;
                  v_cod_sector := v_col_cli_datos(v_idx_tab_cli_datos).cod_sec_contable;
                  v_tip_deudor := v_col_cli_datos(v_idx_tab_cli_datos).cod_tip_deudor;
               ELSIF v_col_cli_datos(v_idx_tab_cli_datos).estado = 'NO_DATA_FOUND' THEN
                  v_mensaje := 'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                  v_hay_error := 'S';
                  --raise_application_error(-20000,'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                  v_err_cliente := 1;
               ELSIF v_col_cli_datos(v_idx_tab_cli_datos).estado = 'TOO_MANY_ROWS' THEN
                  v_mensaje := 'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                  v_hay_error := 'S';
                  -- raise_application_error(-20000,'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                  v_err_cliente := 2;
               ELSE
                  v_mensaje := 'Error al obtener datos del Clie.Princ. : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                  v_hay_error := 'S';
                  v_err_cliente := 3;               
               END IF;

            --3.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
            ELSE
               BEGIN
                  SELECT GE_CLIENTES.RESIDENTE,
                         GE_CLIENTES.COD_SEC_CONTABLE,
                         GE_CLIENTES.COD_TIP_DEUDOR
                    INTO v_residente, v_cod_sector, v_tip_deudor
                    FROM GE_CLIENTES
                    JOIN GE_CTA_CLIENTES ON GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
                   WHERE GE_CTA_CLIENTES.NRO_CUENTA = v_nro_cuenta
                     AND GE_CTA_CLIENTES.RELACION = 'P'
                     AND GE_CTA_CLIENTES.COD_MODULO = v_cod_modulo
                     AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad;

                  --3.2.a Se guardan los datos
                  v_col_cli_datos(v_idx_tab_cli_datos).residente        := v_residente;
                  v_col_cli_datos(v_idx_tab_cli_datos).cod_sec_contable := v_cod_sector;
                  v_col_cli_datos(v_idx_tab_cli_datos).cod_tip_deudor   := v_tip_deudor;
                  v_col_cli_datos(v_idx_tab_cli_datos).estado           := 'OK';
               EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                       v_mensaje := 'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                       v_hay_error   := 'S';
                       --raise_application_error(-20000,'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                       v_err_cliente := 1;

                       --3.2.b Se guarda el estado
                       v_col_cli_datos(v_idx_tab_cli_datos).estado := 'NO_DATA_FOUND';
                   WHEN TOO_MANY_ROWS THEN
                      v_mensaje := 'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                      v_hay_error   := 'S';
                      -- raise_application_error(-20000,'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                      v_err_cliente := 2;

                      --3.2.c Se guarda el estado
                      v_col_cli_datos(v_idx_tab_cli_datos).estado := 'TOO_MANY_ROWS';
               END;
            END IF;

           -- si no hubo error en la busqueda de la Clte Principal---
             IF v_err_cliente = 0 THEN
                IF v_cod_modalidad in (32,37,38) THEN
                   --Busqueda del Plazo de la Cuentas plazo fijo y CDA.---
                   IF v_col_ah_plazo_datos.EXISTS(v_nro_cuenta) THEN
                      v_can_dias := v_col_ah_plazo_datos(v_nro_cuenta);
                   ELSE
                        SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_PLAZOS
                        WHERE NRO_CUENTA = v_nro_cuenta;
                      v_col_ah_plazo_datos(v_nro_cuenta) := v_can_dias;
                   END IF;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                ELSIF v_cod_modalidad in (33,34,35,36) THEN
                   IF v_col_ah_plazo_datos.EXISTS(v_nro_cuenta) THEN
                      v_can_dias := v_col_ah_plazo_datos(v_nro_cuenta);
                   ELSE
                       SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_CERTIFICADOS
                        WHERE NRO_CUENTA = v_nro_cuenta;
                      v_col_ah_plazo_datos(v_nro_cuenta) := v_can_dias;
                   END IF;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                END IF;
                --si es prestamo calculo el plazo entre las fechas
                IF v_cod_modulo = 6 THEN
                   IF v_col_pr_prestamo_datos.EXISTS(v_nro_cuenta) THEN
                      v_can_dias       := v_col_pr_prestamo_datos(v_nro_cuenta).can_dias;
                      v_tip_cuenta     := v_col_pr_prestamo_datos(v_nro_cuenta).tip_cuenta;
                      v_tip_interes    := v_col_pr_prestamo_datos(v_nro_cuenta).tip_interes;
                      v_tip_renovacion := v_col_pr_prestamo_datos(v_nro_cuenta).tip_renovacion;
                      v_cod_sec_rubro  := v_col_pr_prestamo_datos(v_nro_cuenta).cod_sec_rubro;
                      v_est_cuenta     := NVL(v_est_cuenta, v_col_pr_prestamo_datos(v_nro_cuenta).estado_tabla);
                      lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   ELSE
                   BEGIN
                   SELECT FEC_VENCIMIENTO - FEC_INICIO,
                          tipo, tip_interes, nvl(tip_renovacion,'A'),
                          estado, FUP_OBT_SEC_RUBRO(cod_sec_credito)
                    INTO v_can_dias, v_tip_cuenta, v_tip_interes,
                         v_tip_renovacion, v_prestamo_estado_tabla, v_cod_sec_rubro
                    FROM PR_CTA_PRESTAMOS
                   WHERE NRO_CUENTA = v_nro_cuenta;
                     v_col_pr_prestamo_datos(v_nro_cuenta).can_dias       := v_can_dias;
                     v_col_pr_prestamo_datos(v_nro_cuenta).tip_cuenta     := v_tip_cuenta;
                     v_col_pr_prestamo_datos(v_nro_cuenta).tip_interes    := v_tip_interes;
                     v_col_pr_prestamo_datos(v_nro_cuenta).tip_renovacion := v_tip_renovacion;
                     v_col_pr_prestamo_datos(v_nro_cuenta).cod_sec_rubro  := v_cod_sec_rubro;
                     v_col_pr_prestamo_datos(v_nro_cuenta).estado_tabla   := v_prestamo_estado_tabla;
                     v_est_cuenta := NVL(v_est_cuenta, v_prestamo_estado_tabla);
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                     v_mensaje := 'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina;
                     v_hay_error   := 'S';
                         --RAISE_APPLICATION_ERROR(-20000,v_nro_cuenta||'nro_cuenta'||v_nro_cuenta);
                     END;
                   END IF;
                END IF;
                --Agregado para separar contabilizacion de Cta Basica--
                if v_cod_modulo = 3 and v_cod_modalidad = 31 THEN

                   --4. Construir clave para la colección indexada
                   v_idx_tab_ah_datos := v_nro_cuenta;

                   --4.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
                   IF v_col_ah_datos.EXISTS(v_idx_tab_ah_datos) THEN
                      IF v_col_ah_datos(v_idx_tab_ah_datos).estado = 'OK' THEN
                         v_cod_sub_modalidad := v_col_ah_datos(v_idx_tab_ah_datos).cod_sub_modalidad;
                      ELSIF v_col_ah_datos(v_idx_tab_ah_datos).estado = 'NO_DATA_FOUND' THEN
                         v_mensaje := 'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta;
                         v_hay_error   := 'S';
                         -- RAISE_APPLICATION_ERROR(-20000,'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta);
                      ELSE
                         v_mensaje := 'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta;
                         v_hay_error   := 'S';
                      END IF;

                   --4.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
                   ELSE
                      BEGIN
                         select x.cod_sub_modalidad
                         into v_cod_sub_modalidad
                         from ah_cta_vistas x
                         where x.nro_cuenta = v_nro_cuenta;

                         --4.2.a Se guardan los datos
                         v_col_ah_datos(v_idx_tab_ah_datos).cod_sub_modalidad := v_cod_sub_modalidad;
                         v_col_ah_datos(v_idx_tab_ah_datos).estado            := 'OK';
                      EXCEPTION
                         WHEN NO_DATA_FOUND THEN
                            v_mensaje := 'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta;
                            v_hay_error   := 'S';
                            -- RAISE_APPLICATION_ERROR(-20000,'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta);

                            --4.2.b Se guarda el estado
                            v_col_ah_datos(v_idx_tab_ah_datos).estado := 'NO_DATA_FOUND';
                      END;
                   END IF;

                   --5. Construir clave para la colección indexada
                   v_idx_tab_tc_datos := trim(v_cod_modulo)||trim(v_cod_modalidad)||trim(v_cod_sub_modalidad);

                   --5.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
                   IF v_col_tc_datos.EXISTS(v_idx_tab_tc_datos) THEN
                      IF v_col_tc_datos(v_idx_tab_tc_datos).estado = 'OK' THEN
                         v_tip_cuenta := v_col_tc_datos(v_idx_tab_tc_datos).tip_cuenta;
                      ELSE
                         v_tip_cuenta := null;
                      END IF;

                   --5.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
                   ELSE
                      BEGIN
                         v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(v_cod_modulo)||trim(v_cod_modalidad)||trim(v_cod_sub_modalidad));

                         --5.2.a Se guardan los datos
                         v_col_tc_datos(v_idx_tab_tc_datos).tip_cuenta := v_tip_cuenta;
                         v_col_tc_datos(v_idx_tab_tc_datos).estado     := 'OK';
                      EXCEPTION
                         WHEN OTHERS THEN
                            v_tip_cuenta := null;

                            --5.2.b Se guarda el estado
                            v_col_tc_datos(v_idx_tab_tc_datos).estado := 'OTHERS';
                      END;
                   END IF;

                end if;

                --si es MD calculo el plazo entre las fechas
                IF v_cod_modulo = 10 THEN
                   IF v_col_md_documento_datos.EXISTS(v_nro_cuenta) THEN
                      v_can_dias    := v_col_md_documento_datos(v_nro_cuenta).can_dias;
                      v_tip_interes := v_col_md_documento_datos(v_nro_cuenta).tip_interes;
                      v_est_cuenta  := NVL(v_est_cuenta, v_col_md_documento_datos(v_nro_cuenta).estado_tabla);
                      lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   ELSE
                   BEGIN
                   SELECT NVL(FEC_VENCIMIENTO - FEC_INICIO,0),
                          tip_calculo,
                          estado
                    INTO v_can_dias, v_tip_interes,
                         v_md_estado_tabla
                    FROM MD_CTA_DOCUMENTOS
                   WHERE NRO_CUENTA = v_nro_cuenta;
                     v_col_md_documento_datos(v_nro_cuenta).can_dias     := v_can_dias;
                     v_col_md_documento_datos(v_nro_cuenta).tip_interes  := v_tip_interes;
                     v_col_md_documento_datos(v_nro_cuenta).estado_tabla := v_md_estado_tabla;
                     v_est_cuenta := NVL(v_est_cuenta, v_md_estado_tabla);
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                     v_mensaje := 'Error en modulo 10 nro_cuenta'||v_nro_cuenta;
                     v_hay_error   := 'S';
                        --RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                   END IF;
                END IF;
                if v_cod_sit_contable is null then
                  --3. Construir clave para la colección indexada
                  v_idx_tab_cta_datos := v_nro_cuenta||'_'||v_cod_modulo||'_'||v_cod_modalidad;

                  --3.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
                  IF v_col_cta_datos.EXISTS(v_idx_tab_cta_datos) THEN
                     IF v_col_cta_datos(v_idx_tab_cta_datos).estado = 'OK' THEN
                        v_cod_sit_contable := v_col_cta_datos(v_idx_tab_cta_datos).cod_sit_contable;
                     ELSIF v_col_cta_datos(v_idx_tab_cta_datos).estado = 'NO_DATA_FOUND' THEN
                        v_mensaje := 'Cuenta no existe en ge_cuentas '||v_nro_cuenta;
                        v_hay_error   := 'S';
                        --   RAISE_APPLICATION_ERROR(-20000,'Cuenta no existe en ge_cuentas '||v_nro_cuenta);
                     ELSE
                        v_mensaje := 'Error inesperado al obtener cod_sit_contable de la cuenta '||v_nro_cuenta;
                        v_hay_error   := 'S';
                     END IF;

                  --3.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
                  ELSE
                     BEGIN
                        select cod_sit_contable
                          into v_cod_sit_contable
                          from ge_cuentas
                        where nro_cuenta = v_nro_cuenta
                          and cod_modulo = v_cod_modulo
                          and cod_modalidad = v_cod_modalidad;

                        --3.2.a Se guardan los datos
                        v_col_cta_datos(v_idx_tab_cta_datos).cod_sit_contable := v_cod_sit_contable;
                        v_col_cta_datos(v_idx_tab_cta_datos).estado           := 'OK';
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           v_mensaje := 'Cuenta no existe en ge_cuentas '||v_nro_cuenta;
                           v_hay_error   := 'S';
                           --   RAISE_APPLICATION_ERROR(-20000,'Cuenta no existe en ge_cuentas '||v_nro_cuenta);

                             --3.2.b Se guarda el estado
                             v_col_cta_datos(v_idx_tab_cta_datos).estado := 'NO_DATA_FOUND';
                     END;
                  END IF;
                end if;
                /*
                --plazo de CCI, si es vista el plazo es 1
                if v_cod_modulo = 8 and v_cod_modalidad = 81 then
                   BEGIN
                   select decode(tip_cobro,'V',1, fec_vto_plazo - nvl(fec_utilizacion,fec_aprobacion))
                     into v_can_dias
                     from cx_cta_importaciones
                    where nro_cuenta = v_nro_cuenta;
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                end if;
                */
                if v_cod_modulo = 5 then
                   --Se cambia debido a que siempre toma el rubro solamente para la categoria actual
                   --y para las transacciones 944 y 946 se desea tomar según lo registrado con el movimiento--CN 25/04/2004--
                   --para que el cambio afecte solamente a estas transacciones
                   if instr(v_cod_tra_pre_tar,','||v_cod_transaccion||',') = 0 then
                   --- Para la parametrizacion contable el estado de la tarjeta
                   --- se hace igual que el prestamo
                   IF v_col_tarjeta_estado.EXISTS(v_nro_cuenta) THEN
                      v_est_cuenta := v_col_tarjeta_estado(v_nro_cuenta);
                   ELSE
                   select decode(t.cat_automatica,'1','C',
                          '2','V','3','G','4','M','M') estado
                     into v_est_cuenta
                     from ta_cta_tarjetas t
                    where t.nro_cuenta = V_NRO_CUENTA;
                      v_col_tarjeta_estado(v_nro_cuenta) := v_est_cuenta;
                   END IF;
                   end if;
                end if;
                ------------------------------------------------------
                if v_cod_modulo in (4,5,6) then
                   --- Verifico categoria

                   --3. Construir clave para la colección indexada
                   v_idx_tab_cat_datos := v_nro_cuenta||'_'||v_cod_modulo||'_'||v_cod_modalidad;

                   --3.1 Si existe en la colección, ya fue recuperado antes... se obtienen los datos de la colección
                   IF v_col_cat_datos.EXISTS(v_idx_tab_cat_datos) THEN
                      IF v_col_cat_datos(v_idx_tab_cat_datos).estado = 'OK' THEN
                         v_cat_automatica := v_col_cat_datos(v_idx_tab_cat_datos).cat_automatica;
                      ELSIF v_col_cat_datos(v_idx_tab_cat_datos).estado = 'NO_DATA_FOUND' THEN
                         v_cat_automatica := 1;
                      ELSE
                         v_mensaje := 'No se pudo obtener la categoria de la cuenta '||v_nro_cuenta;
                         v_hay_error   := 'S';
                         --raise_application_error(-20000,'No se pudo obtener la categoria de la cuenta '||v_nro_cuenta);
                      END IF;

                   --3.2 Si NO existe en la colección, se ejecuta la query necesaria y se guardan los datos en la colección
                   ELSE
                      BEGIN
                         SELECT fup_obt_categoria(c.cat_automatica, c.cat_subjetiva)
                          INTO v_cat_automatica
                          FROM ge_clientes c
                          INNER JOIN ge_cta_clientes cc ON c.cod_persona = cc.cod_persona
                         WHERE cc.relacion = 'P'
                           AND cc.nro_cuenta = v_nro_cuenta
                           AND cc.cod_modulo = v_cod_modulo
                           AND cc.cod_modalidad = v_cod_modalidad;

                         --3.2.a Se guardan los datos
                         v_col_cat_datos(v_idx_tab_cat_datos).cat_automatica := v_cat_automatica;
                         v_col_cat_datos(v_idx_tab_cat_datos).estado         := 'OK';
                      EXCEPTION
                         WHEN NO_DATA_FOUND THEN
                            v_cat_automatica := 1;

                            --3.2.b Se guarda el estado
                            v_col_cat_datos(v_idx_tab_cat_datos).estado := 'NO_DATA_FOUND';
                         WHEN OTHERS THEN
                            v_mensaje := 'No se pudo obtener la categoria de la cuenta '||v_nro_cuenta;
                            v_hay_error   := 'S';
                            --raise_application_error(-20000,'No se pudo obtener la categoria de la cuenta '||v_nro_cuenta);

                            --3.2.b Se guarda el estado
                            v_col_cat_datos(v_idx_tab_cat_datos).estado := 'OTHERS';
                      END;
                   END IF;
                   --- Recuperar categoria para valuaciones
                   if v_cod_modulo = 6 and v_cod_tra_padre = 150 then
                      if v_nro_documento2 is not null then
                         --- El movimiento trae categoria
                         v_cat_automatica := v_nro_documento2;
                      end if;
                   end if;
                end if;
             END IF;
         ELSIF v_cod_persona is not null then
             -- el movimiento tiene persona identificada, se puede buscar los datos del cliente
             BEGIN
                 SELECT GE_CLIENTES.RESIDENTE,
                        GE_CLIENTES.COD_SEC_CONTABLE,
                        GE_CLIENTES.COD_TIP_DEUDOR
                   INTO v_residente, v_cod_sector, v_tip_deudor
                   FROM GE_CLIENTES
                  WHERE GE_CLIENTES.COD_PERSONA = v_cod_persona;
             EXCEPTION
                 WHEN OTHERS THEN
                      v_residente  := 'S';
                      v_cod_sector := 'N';
                      v_tip_deudor := '2';
             END;
         END IF;
         --------------------------------------------------------------------------
         --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)-------------------
         --Agregado parametros p/ transaccion p/ no contabilizar D/C transitorios--
         --------------------------------------------------------------------------
         IF V_COD_MODULO = 6 THEN --Desembolso, Cobro y Distribucion--
            --DYDMR-12001--Ajuste geberacion unico asiento--
            IF instr(LF_OBT_PAR_TRA_SEG_VIDA(V_COD_TRA_PADRE,V_COD_MOD_PADRE,V_COD_MAD_PADRE),','||TRIM(TO_CHAR(V_COD_TRANSACCION))||',') > 0 THEN
               V_NRO_CTA_AUX := NVL(V_NRO_CUENTA,V_REFERENCIA);
               V_NRO_SOLICITUD := FUG_OBT_NRO_SOLICITUD(V_NRO_CTA_AUX,V_COD_MODULO);
               V_CTA_SEG_DISTR := NVL(fue_tab_dat_adicional('PR_SOLICITUDES', 'PRE_IND_CUO_CAL_SEGURO', V_NRO_SOLICITUD),'N');
            END IF;
         END IF;
         --------------------------------------------------------------------------
        if NVL(V_CTA_SEG_DISTR,'N') = 'S' THEN
           --No debe insertar la linea para no hacer asiento en cta transitoria--
           null;
        elsif v_err_cliente = 0 AND v_detalle IN ('C','D') THEN
           --AND v_usu_insercion <> 'IT' THEN  -- Ajuste temporal para evitar interface (TYS 28-08-2006)
                 --- Busco si existe en Nro. de Referencia del GE_CON_TRANSACCIONES--------
                 BEGIN
                 if v_detallado = 'S' then
                    raise no_data_found;
                 else
                   -- Generar clave de consolidacion (21 campos canonicalizados)
                   v_idx_con_key := FU_GEN_KEY_CACHE(
                      v_fecha, v_cod_mod_padre, v_cod_mad_padre, v_cod_ofi_origen, v_cod_oficina,
                      v_cod_moneda, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_sector,
                      v_tip_deudor, v_residente, v_cod_plazo, v_reversado, v_est_cuenta, v_tip_cuenta,
                      v_tip_interes, v_tip_renovacion, v_cat_automatica, v_cod_sit_contable, v_cod_sec_rubro
                   );

                   IF v_col_con_key.EXISTS(v_idx_con_key) THEN
                      -- cache hit: reutiliza NRO_REFERENCIA y ROWID sin consultar la base
                      v_nro_referencia := v_col_con_key(v_idx_con_key).nro_referencia;
                      v_tra_fila       := v_col_con_key(v_idx_con_key).row_id;
                      v_cache_hits     := v_cache_hits + 1;
                   ELSE
                   SELECT /*+ INDEX(GE_CON_TRANSACCIONES IN_GCTRA_FECHA1)*/ NRO_REFERENCIA,rowid
                     INTO v_nro_referencia,v_tra_fila
                     FROM GE_CON_TRANSACCIONES
                    WHERE FECHA           = v_fecha
                      AND COD_MOD_PADRE   = v_cod_mod_padre
                      AND COD_MAD_PADRE   = v_cod_mad_padre
                      AND COD_OFI_ORIGEN  = v_cod_ofi_origen
                      AND COD_OFICINA     = v_cod_oficina
                      AND COD_MONEDA      = v_cod_moneda
                      AND COD_MODULO      = v_cod_modulo
                      AND COD_MODALIDAD   = v_cod_modalidad
                      AND COD_TRANSACCION = v_cod_transaccion
                      AND COD_SECTOR      = v_cod_sector
                      AND COD_TIP_DEUDOR  = v_tip_deudor
                      AND RESIDENTE       = v_residente
                      AND COD_PLAZO       = v_cod_plazo
                      AND REVERSADO       = v_reversado
                      AND nvl(est_cuenta,'X')     = nvl(v_est_cuenta,'X')
                      AND nvl(tip_cuenta,'X')     = nvl(v_tip_cuenta,'X')
                      AND nvl(tip_interes,'X')    = nvl(v_tip_interes,'X')
                      AND nvl(tip_renovacion,'X') = nvl(v_tip_renovacion,'X')
                      AND nvl(cat_automatica,'9') = nvl(v_cat_automatica,'9')
                      and nvl(cod_sit_contable,-1) = nvl(v_cod_sit_contable,-1)
                      and (nvl(v_detallado,'N') = 'N' and concepto is null)
                      and cod_sec_rubro = nvl(v_cod_sec_rubro,'N');
                   -- primera vez para esta clave: guardar en cache
                   v_col_con_key(v_idx_con_key).nro_referencia := v_nro_referencia;
                   v_col_con_key(v_idx_con_key).row_id         := v_tra_fila;
                   END IF;
                   
                   if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                      v_mto_equ_local := round(nvl(v_monto,0) * LF_OBT_COTIZACION(v_cod_moneda),0);
                   end if;
                   ------------------------------------------------------------------
                    -- Llenar las colecciones con los ROWID y los valores asociados luego realizo update por forall
                   if v_hay_error = 'N' THEN
                     v_con_fila_tab.EXTEND;
                     v_cantidad_tab.EXTEND;
                     v_monto_tab.EXTEND;
                     v_mto_equ_local_tab.EXTEND;

                     v_con_fila_tab(v_con_fila_tab.COUNT) := v_tra_fila;
                     v_cantidad_tab(v_cantidad_tab.COUNT) := 1;
                     v_monto_tab(v_monto_tab.COUNT) := v_monto;
                     v_mto_equ_local_tab(v_mto_equ_local_tab.COUNT) := v_mto_equ_local;
                   END IF;

                 end if;
                   --------------------------------------------------------
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      -- asigno sgte.valor al Nro.Ref e incremento contador--
                      v_nro_referencia := v_sig_nro_referencia;
                      v_sig_nro_referencia := nvl(v_sig_nro_referencia,0) + 1;
                       if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                          v_mto_equ_local := round(nvl(v_monto,0) * LF_OBT_COTIZACION(v_cod_moneda),0);
                       end if;
                      -- para interfaz con la as/400
                      if v_detallado = 'S' then
                          begin
                            v_mov.cod_modulo         := reg_movimientos(i).cod_modulo;
                            v_mov.cod_modalidad      := reg_movimientos(i).cod_modalidad;
                            v_mov.nro_cuenta         := reg_movimientos(i).nro_cuenta;
                            v_mov.monto              := reg_movimientos(i).monto;
                            v_mov.cod_tra_padre      := reg_movimientos(i).cod_tra_padre;
                            v_mov.reversado          := reg_movimientos(i).reversado;
                            v_mov.cod_mod_padre      := reg_movimientos(i).cod_mod_padre;
                            v_mov.cod_mad_padre      := reg_movimientos(i).cod_mad_padre;
                            v_mov.cod_transaccion    := reg_movimientos(i).cod_transaccion;
                            v_mov.cod_moneda         := reg_movimientos(i).cod_moneda;
                            v_mov.nro_documento2     := reg_movimientos(i).nro_documento2;
                            v_mov.concepto           := reg_movimientos(i).concepto;
                            v_mov.cod_persona        := reg_movimientos(i).cod_persona;
                            v_mov.cod_ref_cambio     := reg_movimientos(i).cod_ref_cambio;
                            v_mov.cod_usuario        := reg_movimientos(i).cod_usuario;
                            v_mov.hora               := reg_movimientos(i).hora;
                            v_mov.referencia         := reg_movimientos(i).referencia;
                            v_mov.nro_secuencia      := reg_movimientos(i).nro_secuencia;
                            v_mov.cod_rubro          := reg_movimientos(i).cod_rubro;
                            v_mov.fecha              := reg_movimientos(i).fecha;
                            v_mov.cod_tip_ope_cambio := reg_movimientos(i).cod_tip_ope_cambio;
                            v_mov.nro_documento      := reg_movimientos(i).nro_documento;
                            v_mov.tip_mov_rubro      := reg_movimientos(i).tip_mov_rubro;
                            v_mov.nro_documento3     := reg_movimientos(i).nro_documento3;

                            v_concepto := substr(nvl(LF_OBT_REFERENCIA(v_mov),v_concepto),1,100);
                          exception
                             when others then
                                v_concepto := null;
                               -- raise_application_error(-20000,'Error al obtener Referencia  Hr: '||v_hora||
                               --                        ' Sec:'||v_nro_secuencia||' Ct:'||v_nro_cuenta||'-'||sqlerrm);
                          end;
                      end if;

                      -- no existe registro, se debe generar ----------------
                      INSERT INTO GE_CON_TRANSACCIONES
                          (FECHA,COD_MOD_PADRE,COD_MAD_PADRE,COD_OFI_ORIGEN,
                           COD_OFICINA,COD_MONEDA,COD_MODULO,COD_MODALIDAD,
                           COD_TRANSACCION,COD_SECTOR,COD_TIP_DEUDOR,RESIDENTE,
                           COD_PLAZO,CANTIDAD,TOTAL,TOT_MON_LOCAL,
                           est_cuenta, tip_cuenta, tip_interes, tip_renovacion,
                           cat_automatica, NRO_REFERENCIA, cod_sit_contable,
                           nro_cuenta, concepto, cod_sec_rubro, REVERSADO, cod_tra_padre)
                       VALUES
                          (v_fecha,v_cod_mod_padre,v_cod_mad_padre,v_cod_ofi_origen,
                           v_cod_oficina,v_cod_moneda,v_cod_modulo,v_cod_modalidad,
                           v_cod_transaccion,v_cod_sector,v_tip_deudor,v_residente,
                           v_cod_plazo,1         ,v_monto,v_mto_equ_local,
                           v_est_cuenta, v_tip_cuenta, v_tip_interes, v_tip_renovacion,
                           v_cat_automatica, v_nro_referencia, v_cod_sit_contable,
                           decode(v_detallado,'S',v_nro_cuenta, null),
                           decode(v_detallado,'S',v_concepto, null),
                           nvl(v_cod_sec_rubro,'N'), v_reversado, v_cod_tra_padre)
                       RETURNING rowid INTO v_tra_fila;
                      -- cachear clave no-detallada para que movimientos siguientes del mismo grupo no repitan SELECT
                      if v_detallado != 'S' then
                         v_col_con_key(v_idx_con_key).nro_referencia := v_nro_referencia;
                         v_col_con_key(v_idx_con_key).row_id         := v_tra_fila;
                      end if;
                         ------------------------------------------------------
                    WHEN TOO_MANY_ROWS THEN
                       v_hay_error := 'S';
                        raise_application_error(-20000,'Reg. dup. GE_CON_TRANSACCIONES '||
                       to_char(v_fecha,'dd/mm/yyyy')||'-op:'||v_cod_mod_padre||'-ap:'||
                       v_cod_mad_padre||'-oo:'||v_cod_ofi_origen||'-of:'||v_cod_oficina||'-mn:'||
                       v_cod_moneda||'-mo:'||v_cod_modulo||'-cm:'||v_cod_modalidad||'-ct:'||
                       v_cod_transaccion||'-cs:'||v_cod_sector||'-td:'||v_tip_deudor||'-r:'||
                       v_residente||'-cp:'||v_cod_plazo||'-ec:'||v_est_cuenta||'-tc:'||
                       v_tip_cuenta||'-ti:'||v_tip_interes||'-tr:'||v_tip_renovacion||'-ca:'||
                       v_cat_automatica||'-sc:'||v_cod_sit_contable);
                 END;
                --- actualizo el mov. del GE_MOVIMIENTOS con el nro. de ref.-----
                 -- Llenar las colecciones con los ROWID y los valores asociados
               ----------------------------------------------------------
                if v_hay_error = 'N' THEN
                 v_mov_fila_tab.EXTEND;
                 v_nro_doc4_tab.EXTEND;
                 v_protegido_tab.EXTEND;

                 v_mov_fila_tab(v_mov_fila_tab.COUNT) := v_mov_fila;
                 v_nro_doc4_tab(v_nro_doc4_tab.COUNT) := v_nro_referencia;
                 v_protegido_tab(v_protegido_tab.COUNT) := 'S';
                ------PARA REGISTROS PROCESADOS
                   v_fecha_tab.EXTEND;
                    v_hora_tab.EXTEND;
                    v_usuario_tab.EXTEND;
                    v_secuencia_tab.EXTEND;
                    v_procesado_tab.EXTEND;
                    v_mensaje_tab.EXTEND;
                    v_reversado_tab.EXTEND;
                    v_nro_referencia_tab.EXTEND;
                    v_monto_gp_tab.EXTEND;
                    v_mto_equ_local_gp_tab.EXTEND;

                    v_fecha_tab (v_fecha_tab.COUNT) := V_FEC_MOV;
                    v_hora_tab (v_hora_tab.COUNT):= v_hora;
                    v_usuario_tab (v_usuario_tab.COUNT) := v_cod_usuario;
                    v_secuencia_tab (v_secuencia_tab.COUNT) := v_nro_secuencia;
                    v_procesado_tab (v_procesado_tab.COUNT):= 'S';
                    v_mensaje_tab   (v_mensaje_tab.COUNT)     := v_mensaje;
                    v_reversado_tab   (v_reversado_tab.COUNT)   := V_REVERSADO;
                    v_nro_referencia_tab (v_nro_referencia_tab.COUNT):= v_nro_referencia;
                    v_monto_gp_tab   (v_monto_gp_tab.COUNT)   := V_MONTO;
                    v_mto_equ_local_gp_tab   (v_mto_equ_local_gp_tab.COUNT)   := V_MTO_EQU_LOCAL;

                  -- v_mensaje2:= ('Fecha '|| V_FEC_MOV ||' hora '||v_hora||' usuario '||v_cod_usuario||' nro_sec '||v_nro_secuencia );
             else
                               ------PARA REGISTROS PROCESADOS
                   v_fecha_tab.EXTEND;
                    v_hora_tab.EXTEND;
                    v_usuario_tab.EXTEND;
                    v_secuencia_tab.EXTEND;
                    v_procesado_tab.EXTEND;
                    v_mensaje_tab.EXTEND;
                    v_reversado_tab.EXTEND;
                    v_nro_referencia_tab.EXTEND;
                    v_monto_gp_tab.EXTEND;
                    v_mto_equ_local_gp_tab.EXTEND;
                    
                    v_fecha_tab (v_fecha_tab.COUNT) := V_FEC_MOV;
                    v_hora_tab (v_hora_tab.COUNT):= v_hora;
                    v_usuario_tab (v_usuario_tab.COUNT) := v_cod_usuario;
                    v_secuencia_tab (v_secuencia_tab.COUNT) := v_nro_secuencia;
                    v_procesado_tab (v_procesado_tab.COUNT):= 'N';
                    v_mensaje_tab   (v_mensaje_tab.COUNT)     := v_mensaje;
                    v_reversado_tab   (v_reversado_tab.COUNT)   := V_REVERSADO;
                    v_nro_referencia_tab (v_nro_referencia_tab.COUNT):= v_nro_referencia;
                    v_monto_gp_tab   (v_monto_gp_tab.COUNT)   := V_MONTO;
                    v_mto_equ_local_gp_tab   (v_mto_equ_local_gp_tab.COUNT)   := V_MTO_EQU_LOCAL;
               END IF;
         END IF;
         ---------------------------------------------------------------
      END IF;
             
   END LOOP;

   -- Monitoreo de avance
   v_mensaje := 'Registros procesados: ' || v_rowcount || ' de ' || v_can_movimiento;
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
   it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', v_mensaje, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

      --CONFIRMACIÓN POR LOTE para liberar locks y reducir contención.
      
      it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'Lote '||v_lote||' GE_CON_TRANSACCIONES upd='||v_con_fila_tab.COUNT, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      -- Usar FORALL para el UPDATE en GE_CON_TRANSACCIONES
      IF v_con_fila_tab.COUNT > 0 THEN
         FORALL i IN 1..v_con_fila_tab.COUNT
           UPDATE GE_CON_TRANSACCIONES
              SET CANTIDAD = NVL(CANTIDAD, 0) + v_cantidad_tab(i),
                  TOTAL = NVL(TOTAL, 0) + v_monto_tab(i),
                  TOT_MON_LOCAL = NVL(TOT_MON_LOCAL, 0) + v_mto_equ_local_tab(i)
            WHERE ROWID = v_con_fila_tab(i);
      END IF;

      it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'Lote '||v_lote||' GE_MOVIMIENTOS upd='||v_mov_fila_tab.COUNT, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      -- Usar FORALL para el UPDATE en GE_MOVIMIENTOS
      IF v_mov_fila_tab.COUNT > 0 THEN
         FORALL i IN 1..v_mov_fila_tab.COUNT
           UPDATE GE_MOVIMIENTOS
              SET PROTEGIDO = v_protegido_tab(i),
                  NRO_DOCUMENTO4 = v_nro_doc4_tab(i)
            WHERE ROWID = v_mov_fila_tab(i);
      END IF;

      it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'Lote '||v_lote||' GE_CON_TRA_PROCESOS ins='||v_fecha_tab.COUNT, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      IF v_fecha_tab.COUNT > 0 THEN
         FORALL i IN 1..v_fecha_tab.COUNT
            INSERT INTO it.GE_CON_TRA_PROCESOS (fecha,
                                            hora,
                                            cod_usuario,
                                            nro_secuencia,
                                            Procesado,
                                            mensaje,
                                            reversado,
                                            nro_referencia,
                                            monto,
                                            mto_equ_local)
                              VALUES (v_fecha_tab(i),
                                      v_hora_tab(i),
                                      v_usuario_tab(i),
                                      v_secuencia_tab(i),
                                      v_procesado_tab(i),
                                      v_mensaje_tab(i),
                                      v_reversado_tab(i),
                                      v_nro_referencia_tab(i),
                                      v_monto_gp_tab(i),
                                      v_mto_equ_local_gp_tab(i));
      END IF;

      -- Actualizo el Sgte.Nro.Ref de la tabla GE_PAR_DINAMICOS -----------
      PRG_ACT_PAR_DINAMICO('SIG_NRO_REFERENCIA',v_cod_modulo, v_cod_modalidad,v_cod_moneda, v_cod_oficina,v_sig_nro_referencia);

      COMMIT;  -- confirmado el lote, se liberan locks y se consolida el avance

      -- Reiniciar colecciones para el siguiente lote
      v_con_fila_tab        := t_con_fila_tab();
      v_cantidad_tab        := t_cantidad_tab();
      v_monto_tab           := t_monto_tab();
      v_mto_equ_local_tab   := t_mto_equ_local_tab();
      v_mov_fila_tab        := t_mov_fila_tab();
      v_nro_doc4_tab        := t_nro_doc4_tab();
      v_protegido_tab       := t_protegido_tab();
      v_fecha_tab           := t_fecha_tab();
      v_hora_tab            := t_hora_tab();
      v_usuario_tab         := t_usuario_tab();
      v_secuencia_tab       := t_secuencia_tab();
      v_procesado_tab       := t_procesado_tab();
      v_mensaje_tab         := t_mensaje_tab();
      v_reversado_tab       := t_reversado_tab();
      v_nro_referencia_tab  := t_nro_referencia_tab();
      v_monto_gp_tab        := t_monto_gp_tab();
      v_mto_equ_local_gp_tab := t_mto_equ_local_gp_tab();

   EXIT WHEN cursor1%NOTFOUND;
  END LOOP;
  CLOSE cursor1;

   it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'Finalización... - movs:'||v_rowcount||
                             ' lotes:'||v_lote||' keys_cache:'||v_col_con_key.COUNT||
                             ' hits_cache:'||v_cache_hits||' keys_cotizacion:'||v_cotizacion_cache.COUNT||
                             ' keys_seg_distr:'||v_par_tra_cache.COUNT
                             , it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
  -------------------------------------------------------------
   --- Actualizar cotización
   LP_EQU_MON_LOCAL; --- Puesto por ICL 25/11/2008 transferido del pra_gen_asientos para las equivalencias pasen a los historicos y se utilicen para reversiones
   COMMIT;
  ---Se agrega control para saber desde donde es lanzado--
  /*Solo cortara el proceso, si es lanzado desde el cierre*/
 if P_LUGAR = 'C' then 
  begin
    select count(distinct(a.mensaje))
    into v_cant
    from GE_CON_TRA_PROCESOS a
    where a.fecha = v_fecha 
     and  a.procesado = 'N';
   if nvl(v_cant,0) > 1 THEN
     raise_application_error(-20000,'Existen '||v_cant||' Registros no procesados por errores favor verificar en la tabla it.GE_CON_TRA_PROCESOS');
   elsif nvl(v_cant,0) = 1 then
     select a.mensaje
     into v_mensaje_ex
     from GE_CON_TRA_PROCESOS a
     where a.fecha = v_fecha 
     and  a.procesado = 'N'
     group by a.mensaje ;
     raise_application_error(-20000,'ERROR '||v_mensaje_ex);
   END IF;
   end;
    ----actualiza movimientos procesados con fecha adelantada-----
    begin
        update ge_con_tra_procesos a
        set a.fecha = v_fecha,
            a.mensaje = 'Fecha Anterior '||a.fecha
        where a.fecha > v_fecha
        and   a.procesado = 'S';
      exception
        when others then
          raise_application_error(-20001,'Error al actualizar en ge_con_tra_procesos fechas adelantadas '||sqlerrm);
       end;
       commit;
  END IF;

   -- En modo cierre cierre, lanzar limpieza historica masiva en segundo plano al finalizar el proceso.
  IF P_LUGAR = 'C' THEN
      v_del_fec := TRUNC(v_fec_anterior - v_dia_lim);
      v_del_job_name := 'JOB_PRA_CON_TRA_DEL_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3');
      BEGIN
         DBMS_SCHEDULER.CREATE_JOB(
             job_name   => v_del_job_name,
             job_type   => 'PLSQL_BLOCK',
             job_action => 'BEGIN ' ||
                           '  DELETE FROM GE_CON_TRA_PROCESOS WHERE FECHA <= TO_DATE('''||TO_CHAR(v_del_fec,'DD/MM/YYYY')||''',''DD/MM/YYYY''); ' ||
                           '  it.pag_cie.PR_AT_INS_LOG(11,367,''PRA_CON_TRANSACCION'', ''JOB delete finalizado='||v_del_job_name||' Fecha='||TO_CHAR(v_del_fec,'DD/MM/YYYY')||' filas borradas=''||SQL%ROWCOUNT, it.pag_cie.c_log_TRACE,''OUT'',SYSDATE); ' ||
                           '  COMMIT; ' ||
                           'END;',
             start_date => SYSTIMESTAMP,
             enabled    => FALSE,
             auto_drop  => TRUE,
             comments   => 'Limpieza historica asincrona GE_CON_TRA_PROCESOS desde PRA_CON_TRANSACCION'
         );
         DBMS_SCHEDULER.ENABLE(v_del_job_name);
         
         -- Este log avisa que el proceso principal delegó la tarea exitosamente
         it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'JOB Delete historico lanzado='||v_del_job_name||' Fecha='||TO_CHAR(v_del_fec,'DD/MM/YYYY'), it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
         
      EXCEPTION
         WHEN OTHERS THEN
            it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'No se pudo lanzar JOB Delete historico: '||SQLERRM, it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
      END;
   END IF;

   -- LIMPIAR la salida
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'FIN!', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
exception
when others then
   -- LIMPIAR la salida
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   it.pag_cie.PR_AT_INS_LOG(11,367,'PRA_CON_TRANSACCION', 'EXCEPTION!', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   raise_application_error(-20000,'Ref: '||v_sig_nro_referencia||' hora '||v_hora||' '||v_nro_cuenta||' '||' error '||v_err_cliente||sqlerrm);
END;
/
