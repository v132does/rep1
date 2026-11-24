CREATE OR REPLACE PACKAGE IT.PAG_EXT
IS
   vg_intervalo_size         PLS_INTEGER;
   vg_bulk_size              PLS_INTEGER;
   vg_job_cant_instancias    PLS_INTEGER;
   vg_max_loop_intervalos    PLS_INTEGER;
   vg_timeout_pool_MI        PLS_INTEGER;
   vg_timeout_job_MI         PLS_INTEGER;
   vg_max_movimientos        PLS_INTEGER;
   vg_ult_pri_dia_mes_habil  DATE;
   vg_fec_ult_cierre_mes     DATE;
   vg_pkg                    CONSTANT VARCHAR2(7) := 'PAG_EXT';
   vg_cod_programa           ge_log_errores.cod_programa%TYPE:= 'PAG_EXT.PR_ACT_EXT_MAESTRAS';

   TYPE cta_record IS RECORD (
      cod_persona    VARCHAR2(10),
      cod_modulo     NUMBER(3,0),
      cod_modalidad  NUMBER(3,0)
   );
   TYPE mov_mas_record IS RECORD (
      cod_persona     VARCHAR2(10),
      nro_cuenta      VARCHAR2(15),
      cod_modulo      NUMBER(3,0),
      cod_modalidad   NUMBER(3,0),
      cod_oficina     NUMBER(3,0),
      fec_movimiento  DATE
   );

   TYPE t_cta_table         IS TABLE OF cta_record;
   TYPE t_mov_mas_table     IS TABLE OF mov_mas_record;
   TYPE t_cod_persona_table IS TABLE OF ba_personas.cod_persona%TYPE;

   --Prioridad 1, Personas Jurídicas
   CURSOR cur_per_juridicas (
      p_pri_dia_mes_habil IN DATE,
      p_min               IN VARCHAR2 DEFAULT '0',
      p_max               IN VARCHAR2 DEFAULT RPAD('9', 10, '9')
   ) IS
      SELECT DISTINCT ge_cta_clientes.cod_persona
      FROM ge_cuentas,
           ge_cta_clientes,
           ba_personas
      WHERE ge_cuentas.cod_modulo = ge_cta_clientes.cod_modulo
        AND ge_cuentas.cod_modalidad = ge_cta_clientes.cod_modalidad
        AND ge_cuentas.cod_oficina = ge_cta_clientes.cod_oficina
        AND ge_cuentas.nro_cuenta = ge_cta_clientes.nro_cuenta
        AND ge_cta_clientes.cod_persona = ba_personas.cod_persona
        AND ba_personas.tipo = 'J'
        AND ba_personas.cod_persona BETWEEN p_min AND p_max  --Opción para reconstruir un Intervalo
        AND ge_cuentas.fre_extracto = 'M'
        AND ge_cta_clientes.relacion = 'P'
        AND ge_cuentas.cod_modulo != 5
        AND ( ( ge_cuentas.estado NOT IN ( 'X', 'A', 'C', 'P' ) )
              OR ( ge_cuentas.estado IN ( 'C', 'P' )
                   AND ge_cuentas.fec_modificacion >= p_pri_dia_mes_habil ) )
      ORDER BY ge_cta_clientes.cod_persona;

   --Prioridades 2-3, Personas Físicas
   CURSOR cur_per_fisicas (
      p_pri_dia_mes_habil IN DATE,
      p_segmento          IN PLS_INTEGER,
      p_min               IN VARCHAR2 DEFAULT '0',
      p_max               IN VARCHAR2 DEFAULT RPAD('9', 10, '9')
   ) IS
      SELECT DISTINCT ge_cta_clientes.cod_persona
      FROM ge_cuentas,
           ge_cta_clientes,
           ba_personas,
           ge_clientes
      WHERE ge_cuentas.cod_modulo = ge_cta_clientes.cod_modulo
        AND ge_cuentas.cod_modalidad = ge_cta_clientes.cod_modalidad
        AND ge_cuentas.cod_oficina = ge_cta_clientes.cod_oficina
        AND ge_cuentas.nro_cuenta = ge_cta_clientes.nro_cuenta
        AND ge_cta_clientes.cod_persona = ba_personas.cod_persona
        AND ge_clientes.cod_persona = ba_personas.cod_persona
        AND ba_personas.tipo = 'F'
        AND ( ( p_segmento = 1 AND ge_clientes.cod_seg_cliente in (5, 6) )
               OR ( p_segmento = 2 AND ( ge_clientes.cod_seg_cliente not in (5, 6)
                                         OR ge_clientes.cod_seg_cliente IS NULL ) ) )
        AND ba_personas.cod_persona BETWEEN p_min AND p_max  --Opción para reconstruir un Intervalo
        AND ge_cuentas.fre_extracto = 'M'
        AND ge_cta_clientes.relacion = 'P'
        AND ge_cuentas.cod_modulo != 5
        AND ( ( ge_cuentas.estado NOT IN ( 'X', 'A', 'C', 'P' ) )
              OR ( ge_cuentas.estado IN ( 'C', 'P' )
                   AND ge_cuentas.fec_modificacion >= p_pri_dia_mes_habil ) )
      ORDER BY ge_cta_clientes.cod_persona;

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Monitorear, ejecutar y supervisar, en paralelo, el procedimiento parametrizado.
   */
   PROCEDURE GEN_EXT_MONITOR (
      p_procedure_name IN VARCHAR2
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Poblar la Tabla GE_EXT_INTERVALOS a través de la generación de intervalos ponderados.
   */
   PROCEDURE PR_INT_GENERAR (
      p_pri_dia_mes_habil IN DATE
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Procesar N intervalos según orden de prioridad.
   */
   PROCEDURE PR_INT_PROCESAR (
      p_pri_dia_mes_habil IN DATE,
      p_cant_intervalos   IN PLS_INTEGER DEFAULT 1
   );

   /*
      17-10-2024  v1.0  LReyes
      OBJETIVO: Revertir un intervalo determinado, eliminando todos los extractos generados para el mismo.
   */
   PROCEDURE PR_INT_REVERTIR (
      p_pri_dia_mes_habil IN DATE,
      p_fec_ult_extracto  IN DATE,
      p_cod_cota_inferior IN VARCHAR2,
      p_cod_cota_superior IN VARCHAR2,
      p_depura_selector   IN VARCHAR2 DEFAULT 'TODO'
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Revertir todos los intervalos de un determinado mes, eliminando todos los extractos generados para el mismo.
   */
   PROCEDURE PR_INT_REVERTIR (
      p_pri_dia_mes_habil IN DATE,
      p_fec_ult_extracto  IN DATE
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Elimina todos los intervalos ponderados generados para un determinado mes.
   */
   PROCEDURE PR_INT_ELIMINAR (
      p_pri_dia_mes_habil IN DATE
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Recuperar la Lista de Clientes que pertenecen a un determinado intervalo ponderado.
   */   
   PROCEDURE PR_INT_CLI_LISTAR (
      p_pri_dia_mes_habil IN DATE,
      p_cod_cota_inferior IN VARCHAR2,
      p_cod_cota_superior IN VARCHAR2,
      p_cod_persona_list  OUT t_cod_persona_table
   );

   /*
      23-09-2024  v1.0  EMilanese
      OBJETIVO: Depurar los Clientes listados eliminando aquellos que deben ser excluidos (Blacklist y Extractos ya generados).
   */
   PROCEDURE PR_INT_CLI_DEPURAR (
      p_fec_ult_extracto IN DATE,
      p_cod_persona_list IN OUT t_cod_persona_table,
      p_selector         IN VARCHAR2 DEFAULT 'TODO'
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Generar Extractos a partir de la Lista de Clientes parametrizada.
   */ 
   PROCEDURE PR_GEN_EXTRACTO (
      p_frecuencia  IN VARCHAR2 DEFAULT 'M',
      p_cod_persona_list IN t_cod_persona_table
   );

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Sobrecargar SP, para Generar Extractos a partir de un único Cliente parametrizado.
   */ 
   PROCEDURE PR_GEN_EXTRACTO (
      p_frecuencia  IN VARCHAR2 DEFAULT 'M',
      p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL
   );

   /*
      23-09-2024  v1.0  EMilanese
      OBJETIVO: Eliminar Extractos a partir de la Lista de Clientes parametrizada.
   */ 
   PROCEDURE pr_eli_extracto (
      p_fec_extracto      IN ge_ext_clientes.fec_extracto%TYPE, 
      p_cod_persona_list  IN t_cod_persona_table
   );

   /*
      19-09-2024  v1.0  Ctimossi
      OBJETIVO: Actualización masiva de los datos de extractos en las tablas maestro: cc_cta_corrientes, cc_cta_bancarias, ah_cta_vistas
                Este proceso se ejecuta dentro del proceso de cierre diario con una restricción de tiempo que es configurable.
   */ 
   PROCEDURE pr_act_ext_maestras;
   
   /*
      19-09-2024  v1.0  Ctimossi
      OBJETIVO: Logueo de errores
   */   
   PROCEDURE pr_ins_log_error (
      p_det_error   ge_log_errores.det_error%TYPE,
      p_nro_cuenta  ge_log_errores.nro_cuenta%TYPE
   );

   /*
      04-10-2024  v1.0  LReyes
      OBJETIVO: Procedimiento invocante a ser incluido en la cadena de Inicio de Día para la generación de extractos.
   */ 
   PROCEDURE PR_GEN_EXT_MENSUAL;

   /*
      04-10-2024  v1.0  LReyes
      OBJETIVO: Procedimiento invocante a ser incluido en la cadena de Fin de Día para la actualización de tablas maestro.
   */ 
   PROCEDURE PR_ACT_EXT_MAESTROS;

   /*
      23-09-2024  v1.0  LReyes
      OBJETIVO: Setear los valores configurados en la base de datos para el uso del package.
   */ 
   PROCEDURE PR_SET_PARAMETROS;
   
END PAG_EXT;
/
