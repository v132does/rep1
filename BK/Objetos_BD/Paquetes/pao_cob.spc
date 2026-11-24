CREATE OR REPLACE PACKAGE IT.pao_cob IS
   /**Paquete para envio de Cobranzas a Informconf, aqui se cargan todas las tablas
   Utilizadas para INFORMCONF y se genera el Ascii de Cobranzas .cob**/
   -- Variables utilizadas para cargar datos de archivos cd_rs_%
   type ref_archivo is record(
    columna1   varchar2(1000),
    columna2   varchar2(1000),
    columna3   varchar2(1000),
    columna4   varchar2(1000),
    columna5   varchar2(1000),
    columna6   varchar2(1000),
    columna7   varchar2(1000),
    columna8   varchar2(1000),
    columna9   varchar2(1000),
    columna10   varchar2(1000),
    columna11   varchar2(1000),
    columna12   varchar2(1000),
    columna13   varchar2(1000),
    columna14   varchar2(1000),
    columna15   varchar2(1000),
    columna16   varchar2(1000),
    columna17   varchar2(1000),
    columna18   varchar2(1000),
    columna19   varchar2(1000),
    columna20   varchar2(1000));
   type t_archivo_tab is table of ref_archivo index by binary_integer;
   type T_array is table of varchar2(1000) index by binary_integer;

   procedure pr_eje_consulta(p_sql varchar2,p_columnas number,p_filas in out number,p_ref_cursor in out t_archivo_tab,p_error out varchar2);

   /**Deben de estar definidos todos estos parámetros dinámicos inferiores**/

   -- Variable que indica la ejecución del proceso en caso de error al leer Archivo de entrada.
   v_eje_proceso VARCHAR2(1) DEFAULT 'S';
   --Directorio donde se va a generar el archivo de Informconf
   v_directorio VARCHAR2(20) := fug_obt_pardinamico('DIR_INFORMCONF');
   --Código de Afiliado de la Entidad en Informconf
   v_afiliado VARCHAR2(10) := fug_obt_pardinamico('COD_AFI_INFORMCONF');
   --Código de Afinidad de la Tarjeta para Preventivas
   v_afinidad VARCHAR2(1000) := fug_obt_pardinamico('COD_AFI_TARJETA');
   --Total Sobregirado de Cuentas Corrientes
   v_sal_min_sob_cobranzas NUMBER := fug_obt_pardinamico('MIN_MTO_COB_TERCERIZADAS', 4);
   --Saldo Mínimo de Tarjetas para envio de Datos a Informconf
   v_sal_min_tar_cob_informconf NUMBER := fug_obt_pardinamico('MIN_MTO_COB_TERCERIZADAS', 5);
   --Total Vencido + Capital en GS no Vencidos de Préstamos
   v_sal_min_pre_cobranzas NUMBER := fug_obt_pardinamico('MIN_MTO_COB_TERCERIZADAS', 6);
   --Días de Atraso Iníciales de Sobregiros  de Cuentas Corrientes para envío de Datos a Cobranzas Tercerizadas
   v_dia_atr_ini_sob_informconf NUMBER := fug_obt_pardinamico('MIN_DIA_ATR_COB_TERCERIZADAS', 4);
   --Días de Mora Iníciales de Tarjetas para envío de Datos a Cobranzas Tercerizadas
   v_dia_atr_ini_tar_informconf NUMBER := fug_obt_pardinamico('MIN_DIA_ATR_COB_TERCERIZADAS', 5);
   --Días de Atraso Iníciales de Préstamos para envío de Datos a Cobranzas Tercerizadas
   v_dia_atr_ini_pre_informconf NUMBER := fug_obt_pardinamico('MIN_DIA_ATR_COB_TERCERIZADAS', 6);
   --Días de Mora para los clientes VIPS a partir del cual se gestionan las cobranzas
   v_dia_atr_vip_cob_tercerizadas NUMBER := fug_obt_pardinamico('MIN_VIP_DIA_ATR_COB_TER');

   --Dias de Atraso finales de Tarjetas para envio de Datos a Informconf
   --v_dia_atr_fin_tar_informconf NUMBER := fug_obt_pardinamico('DIA_ATR_FIN_TAR_INFORMCONF');
   --Dias de Atraso finales de Préstamos en Informconf
   --v_dia_atr_fin_pre_informconf NUMBER := fug_obt_pardinamico('DIA_ATR_FIN_PRE_INFORMCONF');

   --Total Sobregirado de Cuentas Corrientes
   v_sal_max_sob_cobranzas NUMBER := fug_obt_pardinamico('MAX_MTO_COB_TERCERIZADAS', 4);
   --Monto Máximo de Tarjetas para envío de Datos a Cobranzas
   v_sal_max_tar_cobranzas NUMBER := fug_obt_pardinamico('MAX_MTO_COB_TERCERIZADAS', 5);
   --Total Vencido + Capital en GS no Vencidos de Préstamos
   v_sal_max_pre_cobranzas NUMBER := fug_obt_pardinamico('MAX_MTO_COB_TERCERIZADAS', 6);
   --Tipos de Banca a ser incluidas en Informconf Ej.(1,2,3)
   v_tip_banca VARCHAR2(10) := fug_obt_pardinamico('TIP_BAN_INFORMCONF');
   --Códigos de Transacciones Prohibidas a no ser incluidas Ej(113,116,200)
   v_cod_tra_prohibida VARCHAR2(10) := fug_obt_pardinamico('COD_TRA_PRO_INFORMCONF');
   --Dirección de correo de Informconf a donde se desea enviar el mail
   v_dir_cor_destinatario VARCHAR2(100) := fug_obt_pardinamico('DIR_COR_DES_INF_COBRO');
   --Dirección de Correo desde donde se envia el mail.
   v_dir_cor_remitente VARCHAR2(100) := fug_obt_pardinamico('DIR_COR_REM_INF_COBRO');
   /**Fin de definición de parámetros dinámicos**/

   /* Informconf- Llama a pro_gen_inf_linea , inserta, hace update o borra de co_inf_cob_personas*/
   PROCEDURE pr_gen_inf_arc_cob;
   /* Informconf- Lee de co_inf_cob_diarios  y luego genera el ascii*/
   PROCEDURE pr_gen_inf_archivo(p_fec_envio IN DATE DEFAULT NULL);
   /* Informconf- Inserta en CO_INF_COB_DIARIOS*/
   PROCEDURE pr_gen_inf_linea
   (
      p_linea     co_inf_cob_personas%ROWTYPE,
      p_tip_envio VARCHAR2
   );
   /* Obtiene la Cuenta Cabecera (en mora) del Cliente*/
   FUNCTION fu_obt_cta_cabecera(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;
   /* Determina si un cliente puede ser agendado para cobranzas Banca Personal (siempre que entre en mora).
   TIPO R devuelve S/N segun impedimentos del cliente.
   TIPO D devuelve el detalle de los impedimentos (para saber porqué no cumple las condiciones).*/
   FUNCTION fu_pue_age_cobranzas
   (
      p_cod_persona IN VARCHAR2,
      p_tipo        IN VARCHAR2 DEFAULT 'R'
   ) RETURN VARCHAR2;

   /*Obtiene el tipo de Garantía.*/
   FUNCTION fu_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER;

   /*Devuelve si la persona tiene o no demanda judicial*/
   FUNCTION fu_ver_cli_judicial(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /* Inserta el log en la tabla de logs de cobranzas.*/
   PROCEDURE pr_ins_log
   (
      p_log   IN co_log_asignaciones%ROWTYPE,
      p_error IN BOOLEAN DEFAULT TRUE
   );
   /* Inserta el log en la tabla de logs de cobranzas.*/
   PROCEDURE pr_log
   (
      p_mensaje co_log_asignaciones.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   );
   /* Obtiene el tramo nuevo que le correponde al cliente.*/
   FUNCTION fu_obt_tramo(
                         /*p_tip_gru_cobranza IN VARCHAR2,*/p_cta_cabecera IN VARCHAR2) RETURN NUMBER;
   /* Obtiene el tipo de gestor que corresponde al tramo
   para que las agendas de los abogados se inserten realizadas y no se vuelvan a activar (tramos 4 y 5).*/
   FUNCTION fu_obt_tip_gestor(p_cod_tramo IN NUMBER) RETURN VARCHAR2;
   /* Devuelve los datos si el cliente tiene tramo actual vigente.*/
   PROCEDURE pr_ver_tra_actual
   (
      p_cod_persona        IN VARCHAR2,
      p_tramo              OUT NUMBER,
      p_cod_agenda         OUT NUMBER,
      p_fec_ini_asignacion OUT DATE,
      p_cta_cabecera       OUT VARCHAR2
   );
   /* Proceso de Generacion de asignaciones de cobranzas Bca Personal.*/
   PROCEDURE pr_gen_asignaciones;

   /* Envío de Preventivas - Llama a pro_gen_inf_linea , inserta, hace update o borra de co_inf_cob_personas*/
   PROCEDURE pr_gen_arc_preventivas;

   /* Importación del archivo que contiene el Scoring de las Personas*/
   PROCEDURE pr_sco_importacion;

   /* Importación de los archivos de salida (DIRE, TELE y MAIL) del RecoveryStrategy*/
   PROCEDURE pr_dat_per_importacion;

   /* Actualizacion de los archivos de salida (DIRE, TELE y MAIL) del RecoveryStrategy*/
   PROCEDURE pr_act_dat_personas;
/*   (
      p_referencia    IN VARCHAR2,
      p_tipo_accion   IN VARCHAR2,
      p_tipo_dato_act IN VARCHAR2
   );
*/
   /* Inicio del circuito para el WorkFlow*/
   PROCEDURE pr_ini_circuito;

   /* Obtiene Tipo del Grupo de Cobranzas del Cliente.*/
   FUNCTION fu_obt_tip_gru_cob(p_cod_persona IN VARCHAR2) RETURN VARCHAR2;

   /* Actualiza el Tipo de Agrupación para envios de datos a tercerización de Cobranza (TIP_GRU_COBRANZA) de la tabla GE_CLIENTES*/
   PROCEDURE pr_act_tip_gru_cob;

   /*Generar los archivos txt a partir de las consultas dinámicas.*/
   PROCEDURE pr_exp_consultas;

   /*Ejecuta la Importación del Archivo SCORE y los procesos para generar Archivos de Salida*/
   PROCEDURE pr_gen_arc_recovery;

   /*Genera registros Preventiva Tarjetas y Préstamos*/
   PROCEDURE pr_gen_preventivas;

END pao_cob;
/

