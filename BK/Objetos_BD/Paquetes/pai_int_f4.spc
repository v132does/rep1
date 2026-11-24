CREATE OR REPLACE PACKAGE IT.PAI_INT_F4 is

  -- Author  : XPY3109
  -- Created : 12/05/2010 12:07:21 p.m.
  -- Cambiado : 12/05/2010 12:07:21 p.m. (simgia)
  -- Purpose : Interfaces ITGF - AS400 Fase 4

-- OBTIENE LA FECHA DE INICIO DE MD_DOC_DETALLES
FUNCTION FU_SIM_OBT_FECHAINI_PR_CUOTA(vnro_documento varchar2, vnro_cuota number)
RETURN DATE;

function FU_SIM_OBT_MTO_PR_CUOTA(vnro_cuenta  varchar2, vfecha_inicio  date)
RETURN number;

FUNCTION FU_OBT_CTA_CONTABLE_PR_CUOTA
  (P_COD_RUBRO IN CB_RUBROS.COD_RUBRO%TYPE)
RETURN VARCHAR2;

-- OBTIENE LA FECHA DE INICIO DE MD_DOC_DETALLES
FUNCTION FU_SIM_OBT_FECHAINI_DOC_DET(vnro_documento varchar2, vnro_cuota number)
RETURN DATE;

--OBTIENE EL MONTO MD_DEVENGADO POR NUMERO DE CUENTA Y FECHA DE INICIO OBTENIDO DE LA CUOTA

function FU_SIM_OBT_MTO_MDEV(vnro_cuenta  varchar2, vfecha_inicio  date)
return number;

--Obtiene la Cuenta Contable
FUNCTION FU_OBT_CTA_CONTABLE
  (P_COD_RUBRO IN CB_RUBROS.COD_RUBRO%TYPE)
  RETURN VARCHAR2;

--obtiene cuenta contable intereses en suspenso
FUNCTION FU_OBT_CTA_INT_SUSPENSO
(P_RUBRO VARCHAR2, P_MONEDA NUMBER)
return varchar2;

-- Copia vistas para AS para posterior migración
procedure backup_vistas;

-- Crea archivo de texto de MAECARTERA
procedure GEN_MAECARTERA_PAG;

-- Crea archivo de texto de MAEICPC
procedure GEN_MAEICPC_PAG;

function OBT_COD_AVAL(vnro_cuenta varchar2, vid number)
return varchar2;

-- Crea archivo de texto de GARANTIAS
procedure GEN_GARANIT_PAG;

--Retorna monto de reisgo para informe inventario operaciones a aprovar
function OBT_MONTO_RIESGO (vnro_solicitud varchar2)
return number;

--Actualiza categoria de clientes
PROCEDURE act_cat_clientes;

-- Migracion de categoria de clientes
procedure migrar_interfaz8;

--Se utiliza entra procesos independientes, crea un delay por el tiempo que sea necesario
procedure ctrl_interfaz8;

--Prueba de tarjetas
-- Backup vistas AS400
procedure backup_vistas_t;

-- Migracion de debcrecont
procedure migrar_interfaz9 ;

--Actualiza categoria subjetiva de clientes con datos de MAERECLAS
PROCEDURE act_catsub_clientes;

-- Crea archivo de texto de PREVICAR
procedure GEN_PREVICAR_PAG;

end PAI_INT_F4;
/

