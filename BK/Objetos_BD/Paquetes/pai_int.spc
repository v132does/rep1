CREATE OR REPLACE PACKAGE IT."PAI_INT" is

  -- Author  : PY00315
  -- Created : 10/08/2009 03:47:21 p.m.
  -- Cambiado : 11/09/2009 09:00:00 a.m. (simgia)
  -- Purpose : Interfaces ITGF - AS400

  -- Recuperar la tasa de la cuenta
function fu_obt_val_tasa
     (p_cod_modulo in ge_cuentas.cod_modulo%type,
      p_cod_modalidad in ge_cuentas.cod_modalidad%type,
      p_cod_oficina in ge_cuentas.cod_oficina%type,
      p_nro_cuenta in ge_cuentas.nro_cuenta%type,
      p_cod_moneda in ge_cuentas.cod_moneda%type,
      p_saldo in ge_cuentas.sal_contable%type,
      p_tas_personalizada in ge_cuentas.tas_personalizada%type,
      p_cod_tasa in ge_cuentas.cod_tasa%type,
      p_fec_apertura in ge_cuentas.fec_apertura%type)
return number;

--Obtiene el tipo de deposito
function fu_obt_tip_deposito
     (p_cod_modalidad in ge_cuentas.cod_modalidad%type,
     p_cod_moneda in ba_monedas.cod_moneda%type)
     return number;

--Obtiene Si es Conjunta o Indistinta
function fu_obt_tip_relacion
     (p_nro_cuenta in ge_cuentas.nro_cuenta%type)
     return char;

--Determina si la cuenta esta o no pignorada
function fu_ver_pignoracion
     (p_nro_cuenta in ge_cuentas.nro_cuenta%type)
     return number;

--Obtiene Devengado del CDA
FUNCTION FUI_OBT_DEV_CDA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE
 ,P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE
 ,P_FEC_CALCULO IN DATE
 )
 RETURN NUMBER;

--Obtiene la Clase del Cliente segun BCP
FUNCTION fu_obt_cla_cliente
  (p_cod_persona in ge_clientes.cod_persona%type
  )
return number;

--Obtiene la Cuenta Contable
FUNCTION FU_OBT_CTA_CONTABLE
  (P_COD_RUBRO IN CB_RUBROS.COD_RUBRO%TYPE)
  RETURN VARCHAR2;

--Funcion que trae el estado de la cuenta de un cliente
FUNCTION FU_OBT_EST_CUENTA(P_COD_MODALIDAD  IN GE_EST_CUENTAS.COD_MODALIDAD%TYPE,
                           P_ESTADO  IN GE_EST_CUENTAS.ESTADO%TYPE)
RETURN CHAR;

-- OBTIENE LA FECHA DE INICIO DEL DEVENGAMIENTO
FUNCTION FU_SIM_OBT_FECHAINI(vnro_documento varchar2, vnro_cuota number)
RETURN DATE;

--OBTIENE EL TIPO DE CUENTA PARA LA TABLA ARBOSUBTN
FUNCTION FU_SIM_OBT_TIP_CUENTA(v_cta in number, v_moneda  in  varchar2)
RETURN NUMBER;

--OBTIENE FECHA INICIO DE CUPONES
FUNCTION FU_SIM_OBT_FECHAINI_CUPONES(vnro_cuenta varchar2, vnro_cupon number)
RETURN DATE;

--OBTIENE EL MONTO AH_DEVENGADO POR NUMERO DE CUENTA Y FECHA DE INICIO OBTENIDO DE LA CUOTA
FUNCTION FU_SIM_OBT_MTO_ADEV(vnro_cuenta  varchar2, vnro_cupon  number)
return number;

--OBTIENE EL MONTO AH_DEVENGADO POR NUMERO DE CUENTA Y FECHA DE INICIO OBTENIDO DE LA CUOTA olfmaecda
FUNCTION FU_SIM_OBT_MTO_ADEV_CDA(vnro_cuenta  varchar2, vnro_cupon  number, vfecha_apertura date)
return number;


--OBTIENE EL MONTO MD_DEVENGADO POR NUMERO DE CUENTA Y FECHA DE INICIO OBTENIDO DE LA CUOTA

function FU_SIM_OBT_MTO_MDEV(vnro_cuenta  varchar2, vfecha_inicio  date)
return number;

-- OBTIENE LA FECHA DE INICIO DE MD_DOC_DETALLES
FUNCTION FU_SIM_OBT_FECHAINI_DOC_DET(vnro_documento varchar2, vnro_cuota number)
RETURN DATE;

--OBTIENE EL NRO DE DOCUMENTO DEL CHEQUE PARA TRNCMBPRE
FUNCTION FU_SIM_OBT_DOCUMENTO_TRNCMBPRE(VTRANSACCION IN NUMBER,VMODALIDAD IN NUMBER,
VPADRE IN NUMBER,VRUBRO IN VARCHAR2,VHORA IN VARCHAR2,VFECHA IN DATE) return number;

FUNCTION FU_SIM_OBT_TIPO_TRNCMBPRE(VTRANSACCION IN NUMBER,VMODALIDAD IN NUMBER,
VPADRE IN NUMBER,VRUBRO IN VARCHAR2,VHORA IN VARCHAR2,VFECHA IN DATE) return varchar2;

--OBTIENE EL CODIGO DE BANCO CORRESPONSAL para AS400
FUNCTION FU_SIM_OBT_CODCORR(COD_BCO_CORRESPONSAL in number, COD_MONEDA in varchar2)
         return integer;

--Normaliza una cadena de texto, ajustando longitud y eliminando caracteres especiales
function FU_SIM_NORM_CADENA(cadena in varchar2, long in integer)
return varchar2;

--Obtiene numero de secuencia para cheques anulados
function FU_SIM_OBT_SEC_CHE_ANU(v_cuenta in number)
return number;

--Obtiene numero de secuencia para montos bloqueados
function FU_SIM_OBT_SEC_MNT_BLQ(v_cuenta in number)
return number;

global_nro_cuenta1 number;
global_contador1 number;

global_nro_cuenta number;
global_contador number;

--OBTIENE EL TIPO DE CUENTA PARA LAS TABLAS QUE GUARDAN EL TIPO DE CUENTA EN 3P
FUNCTION FU_SIM_OBT_TIP_CUENTA_3P(v_cta in number, v_moneda  in  varchar2)
RETURN NUMBER;

--Obtiene numero de secuencia para arpaquete
function FU_SIM_OBT_SEC_ARPAQUETE(v_persona in number)
return number;

global_cod_persona_arpaquete number;
global_contador_arpaquete number;

FUNCTION FU_SIM_OBT_TIPO_COMISION(v_cod_transaccion in number, v_tipo_cuenta in number, v_moneda  in  varchar2)
RETURN NUMBER;

--obtiene rubro contable
FUNCTION SIMGIA_FUNC_OBT_RUBRO_CONTABLE(v_cod_tip_asiento in number,
v_cod_moneda in varchar2, v_tip_movimiento varchar2,v_cod_sec_contable in varchar2, v_ind_residente in varchar2)
return varchar2;

-- Crea archivo de texto cc canceladas
procedure cccanceladas_txt;

-- Crea archivo de texto de asientos paginado
FUNCTION GEN_ASIENTOS_PAGINADO
  (p_archivo in varchar2,
   p_corte in number) return varchar2;

-- Crea archivo de texto paginado
/*
FUNCTION PRG_GEN_ARCHIVO_PAGINADO
  (p_archivo in varchar2,
   p_sql in varchar2,
   p_con_cabecera in varchar2 default 'N',
   p_separador in varchar2 default null,
   p_agrega    in varchar2 default 'S',
   p_corte in number) return varchar2;
*/

--FUNCTION obtieneArclinomi RETURN myTableArclinomiType PIPELINED;

/* ejecuta comandos de sistema */
PROCEDURE system_run(cmd IN varchar2, nom_proc IN varchar2 default 'PRG_SIMGIA');

--sleep , fuerza tiempo de espera en segundos
FUNCTION smg_sleep(v_sec IN VARCHAR2 default 0) return timestamp;

-- Migracion de Inicio y fin de dia
procedure  migra_bloqueos;

-- Migracion de Inicio y fin de dia
procedure migrar_interfaz4;

-- Migracion de final del dia
procedure migrar_interfaz5;

-- Migracion de Armamay
procedure migrar_interfaz7;

procedure backup_vistas;

-- Backup tabla procesamiento debcreit
procedure bkp_debcreit;

-- reprocesar estado 9 de debcreit de fecha actual
procedure reproc_debcreit;

-- Backup tabla procesamiento ardeupend
procedure bkp_ardeupend;

-- Verifica existencia de datos actualizados en simgia_debcreit
procedure PRG_DEBCREIT_ACTUALIZADO( RESPUESTA OUT VARCHAR2);

-- Borra registros con fecha actual
procedure DEL_REG_DEBCREIT;

-- actualiza montos de deudas pendientes en la AS400
PROCEDURE ACTUALIZAR_DEU_PEND;

-- Actualiza cb_sal_oficina desde vista (simgia_aldo_oficina) de armamay
procedure actualiza_sal_ofi;

-- Controla ejecucion de procesos de simgia
PROCEDURE ctrl_proc(proceso IN varchar2);

--Controla que proceso independiente de debcreit se ejecute solo una vez al dia
procedure ctrl_debcreit;

--Controla que proceso independiente de ardeupend se ejecute solo una vez al dia
procedure ctrl_ardeupend;

--Controla que proceso independiente de armamay se ejecute solo una vez al dia
procedure ctrl_armamay;

--Controla Termino de migración
function ctrl_migra(proceso IN varchar2) return number;

--Controla que la migracion de Interfaz4 halla concluido para continuar acon sigte proceso
--Se utiliza entra procesos independientes, crea un delay por el tiempo que sea necesario
procedure ctrl_interfaz4;

--Devuelve fecha de venciumiento de ultima cuota exportacion
function exp_fec_ult_cuota(vcuenta IN varchar2) return date;

-- Controla ejecucion de procesos de simgia, por fecha de modulo
PROCEDURE ctrl_proc_fec_mod(proceso IN varchar2, vmodulo IN number);

-- Controla ejecucion de Armamay v2010-09-20
PROCEDURE ctrl_armamay_fec_mod;

--Actualiza fecha de modulo contable, en caso de existir apertura de día
procedure PRB_ACT_CALENDARIO;

function mod_habilitado(vmodulo IN number) return number;

--Extrae el usuario que cargo el asiento contable
function extrae_usuario_asiento(v_fecha IN date, v_nro_doc IN number) return varchar2;

-- calculo de saldo de ctas corriente con lógica del inventario
-- para migración de ARMA700, ARMA709, ARMA711, ARMA719
function calcula_saldo_arma7xx(v_sal_tot_batch IN number,v_sal_ret_batch IN number,v_sal_blo_batch IN number) return number;

-- obtiene sobregiros de ARMA700 y ARMA709
function obt_rub_sobregiro(
v_cod_modulo in ge_cuentas.cod_modulo%type,
v_cod_modalidad in ge_cuentas.cod_modalidad%type,
v_cod_moneda in ge_cuentas.cod_moneda%type,
v_cod_persona VARCHAR2,
v_nro_cuenta VARCHAR2,
v_sal_tot_batch NUMBER ) return varchar2;

end PAI_INT;
/

