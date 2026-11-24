create or replace package it.PAB_CIF is

  -- Author  : XPY3109 NAF - ABR 2019/CORECOIFA-2 
  -- Created : 20/03/2019 12:15:20
  -- Purpose : Paquete de Conciliacion de Ingresos - Facturaciones
  
  -- Inicializa Variables para conciliación
  Procedure pr_ini_variables( p_fec_proceso date default null);
  
  -- Trunca tablas temporales
  Procedure pr_tru_temporales;
  
  -- Copia datos a tablas tmp
  Procedure pr_gen_temporales;
  
  -- Depura tablas tmp
  Procedure pr_dep_facturas;
  
  -- Actualiza tabla de movimientos
  Procedure pr_act_movimientos;
  
  -- Verificacion de existencia de registros a fecha solicitada
  Procedure pr_ver_datos;
  
  -- Verificacion de Fecha de Parametro CIF_FEC_CONCILIACION
  Procedure pr_ver_fecha(p_valor in varchar2);
  
  -- Control de rango de horarios permitidos para el procesamiento
  procedure pr_ver_horarios;
  
  -- Genera achivo desde tabla
  procedure pr_gen_arc_tabla (p_tabla in varchar2);
  
  -- Genera Conciliación 
  Procedure pr_gen_conciliacion( p_fec_proceso date default null);
  
  -- Genera Conciliacion a Fecha Especifica
  Procedure pr_gen_con_fecha;
  
  -- Genera Archivos de Conciliacion
  Procedure pr_gen_archivos( p_fec_proceso date default null);
  
  -- Genera Archivos de Conciliacion a Fecha Especifica
  Procedure pr_gen_arc_fecha;

end PAB_CIF;
/

