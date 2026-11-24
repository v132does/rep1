create or replace package it.pag_rba is
  /**
    -- Author  : CNOGUERA
    -- Created : 21/05/2014
    -- Purpose : Generar archivos que puedan ser procesados en la aplicación RBA
                 La version completa del paquete está aplicada en el DW, esquema RBA.
  **/

  g_path           varchar2(200) := fug_obt_pardinamico('DIR_ARC_RBA');
  g_archivo        varchar(200);
  g_filler         varchar2(1) := chr(32); --' '; --ESPACIO
  g_lugar          varchar2(100);
  g_linea          varchar2(32767);
  --Fecha de Datos o de Procesamiento--
  g_fec_datos      date := pag_cal.fu_obt_fec_actual(1);
  --ultimo dia habil del mes
  g_ult_dia_mes_habil date := pag_cal.fu_obt_fec_habil(last_day(g_fec_datos),-1,2);
  rp_glrba            ge_log_rba%rowtype;

/**Generar JSON**/
--Rutina Local--
/**
   --Tipo consulta como parámetro-- recibe lista_codigo, retorna texto JSON
   --Cclient: Código de cliente (código interno del banco).
   --Identificación: Identificación fiscal del cliente (persona física o jurídica).
   --Denominación: Nombre y Apellidos (persona física) o razón social (persona jurídica) del cliente.
**/
  function fu_obt_datos(p_tipo varchar2, p_criterios clob) return clob;
--Rutina Local--
/**Generar JSON**/


  --Función que establece la fecha de datos o de proceso--
  function fu_set_fec_datos(p_fec_datos date default null) return date;

  --Funcion para obtener la fecha de datos o de proceso--
  function fu_obt_fec_datos return date;
  
  --Funcion que retorna datos para consultas en kyc--
  function fu_wsi_kyc_datos(p_cod_persona in ba_personas.cod_persona%type) return typ_kycdatos;
  
  --Funcion que Inhibe o Deshinibe al Cliente 
  function fu_act_inhibidos(p_cod_persona in varchar2, p_cod_proceso varchar2, p_tip_proceso varchar2, p_tipo varchar2 default 'I') return number;

  -- Procedimiento de insercion de LOG --
  procedure pr_log_rba(rp_glrba ge_log_rba%rowtype);

  -- Procedimiento de insercion de Datos de Clientes --
  procedure pr_dat_clientes(rp_sdc smg_dat_clientes%rowtype);

  -- Actualización de Datos de Clientes RBA --
  procedure pr_act_rba_dat_cliente( p_fec_datos date default null );
  
  -- Procesamiento del Archivo de Bloqueos Masivos RBA --
  procedure pr_pro_blo_masivos;

end pag_rba;
/

