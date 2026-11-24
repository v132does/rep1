CREATE OR REPLACE PACKAGE IT.PA_REP_AUT is

  -- Author  : RICARDO BARRIOS
  -- Created : 13/05/2011..
  -- Purpose : Extraer datos de consultas a un txt, moverlos los archivos a un directorio compartido mediante FTP y enviar mail de aviso a usuario.

/* changelog:
     20120710:fjm: agregue el procedure prg_gen_mov_riegos
*/

-- Variables
  g_repository         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_FTP');
  g_envia_mail         VARCHAR2(100) := fug_obt_dir_correo;
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := fug_obt_pardinamico('PUERTO_FTP');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_compartido         VARCHAR2(100) := '\\192.168.254.136\';
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS')||'\';
  g_contabilidad       VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_CONTABILIDAD');
  g_riesgos            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_RIESGOS');
  g_finanzas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_FINANZAS');
  g_amaral             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_RIESGOS');
  g_compras            VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_COMPRAS');
  g_sistemas           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_SISTEMAS');
  g_extractos          VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_EXTRACTOS');
  g_balances           VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_BALANCES');
  g_infoespana         VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_INF_CIDESA');
  g_infocidesa         VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_INF_CIDESA');
  g_operaciones        VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_OPERACIONES');
  g_conciliaciones     VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_OPERACIONES');

-- Funcion para obtener valores de GE_PAR_RA
FUNCTION fu_obt_valor_par
    (
    v_servicio IN varchar2 DEFAULT 'ALL',
    v_tabla    IN varchar2,
    v_campo    IN varchar2
    )
    RETURN  VARCHAR2;

-- Devengado diario
PROCEDURE pr_dev_dia;                                        -- contabilidad

-- Devengado diario con Rubros
PROCEDURE pr_dev_dia_rub;                                    -- contabilidad

-- Pre Cierre Diario
PROCEDURE pr_pre_cierre;                                     -- contabilidad

-- Inventario de Sobregiros
PROCEDURE pr_sobregiros;                                     -- riesgos

-- Depósitos con Cheque - Detalle Movimiento                 -- contabilidad
PROCEDURE pr_cheq_det_mov;

-- Depósitos con Cheque - Cheques Remitidos Detalle          -- contabilidad
PROCEDURE pr_cheq_rem_det;

-- Depósitos con Cheque - Cheques Remitidos Cabecera         -- contabilidad
PROCEDURE pr_cheq_rem_cab;

-- Previsiones Específicas Resumen                           -- riesgos
PROCEDURE pr_previ_res;

-- Diferencias Bacht del cierre
PROCEDURE pr_bacht_cierre;

-- Validación Diferencia de Posición
PROCEDURE pr_val_dif_posi;

-- Saldos Contables Abierto HISTORICO - AS400
PROCEDURE pr_saldo_imp;                                       -- balances

-- Saldos Contables Abierto por Sucursal HISTORICO - AS400
PROCEDURE pr_sal_cont_suc;                                    -- balances

-- Saldos Contables Sin Signo HISTORICO - AS400
PROCEDURE pr_saldo_cont;                                      -- balances

-- Saldos Contables Con Signos HISTORICO - AS400
PROCEDURE pr_sal_no_signo;                                    -- balances

-- Saldos Contables Con Signos por Sucursal HISTORICO - AS400
PROCEDURE pr_sal_nosig_suc;                                   -- balances

-- Procedimiento para obtener reportes de saldos contables de la AS400
PROCEDURE pr_bal_cerrado;

-- Saldos Promedios Abierto - AS400
PROCEDURE pr_prom_abi;                                        -- balances

-- Saldos Promedios Abierto por Sucursal - AS400
PROCEDURE pr_proabi_suc;                                      -- balances

-- Saldos Promedios Cerrado - AS400
PROCEDURE pr_prom_cerra;                                    -- balances

-- Saldos Promedio Cerrado por Sucursal - AS400
PROCEDURE pr_procer_suc;                                     -- balances

-- Procedimiento para obtener reportes de saldos de promedio de la AS400
PROCEDURE pr_bal_promedio;

-- Saldos Contables Abierto - AS400
PROCEDURE pr_bal_abierto;                                    -- balances

-- Saldos Contables Abierto por Sucursal - AS400
PROCEDURE pr_bal_abi_suc;                                    -- balances

-- Saldos Contables Con Signos - AS400
PROCEDURE pr_balcerra_sig;                                   -- balances

-- Saldos Contables Con Signos por Sucursal - AS400
PROCEDURE pr_balce_sig_suc;                                  -- balances

-- Saldos Contables Sin Signo - AS400
PROCEDURE pr_balan_cerrado;                                   -- balances

-- Procedimiento para obtener reportes de saldos contables Diarios de la AS400
PROCEDURE pr_balcerra_dia;

-- Control de Posición de Cambios formato AS400
PROCEDURE pr_pos_cambio;                                      -- contabilidad

-- Procedimiento para obtener reportes de Control de Posición de Cambios formato AS400
PROCEDURE pr_ctrl_pos_cam;

-- Diferencia ARMAMAY - Balance ITGF
PROCEDURE pr_dif_armamay;                                     -- contabilidad

-- Informes para Casa Matriz en España - ACTPAS
PROCEDURE pr_info_actpas;                                     -- InformesEspana

-- Informes para Casa Matriz en España - BALBBVA
PROCEDURE pr_info_balbbva;                                    -- InformesEspana

-- Informes para Casa Matriz en España - RA13407
PROCEDURE pr_info_ra13407;                                    -- InformesEspana

-- Informes para Casa Matriz en España - RESBBVA
PROCEDURE pr_info_resbbva;                                    -- InformesEspana

-- Procedimiento para obtener reportes de Informes para Casa Matriz en Espana
PROCEDURE pr_info_espana;                                     -- InformesEspana

-- Libro IVA de Ventas Diarios
PROCEDURE pr_iva_venta_di;                                    -- contabilidad


/******* REPORTES MENSUALES *******/


-- Previsiones Específicas Detallado Mensual
PROCEDURE pr_prev_det_mes;                                   -- riesgos

-- Impuestos al Valor Agregado 1                             -- amaral
PROCEDURE pr_imp_va_uno;

-- Impuestos al Valor Agregado 2                             -- amaral
PROCEDURE pr_imp_va_dos;

-- Libro de Compras
PROCEDURE pr_lib_compra;                                     -- amaral

-- Libro de Compras Detallado
PROCEDURE pr_lib_comp_det;                                   -- amaral

-- Retencion Iva
PROCEDURE pr_reten_iva;                                      -- amaral

-- Libro de Ventas
PROCEDURE pr_lib_vta;                                        -- amaral

-- Libro de Ventas Detallado
PROCEDURE pr_lib_vta_det;                                    -- amaral

-- Pagos a Proveedores (Compras Mensuales)
PROCEDURE pr_pag_prov_cm;                                    -- compras

-- Inventario de Devengados Mensual al Cierre del Mes
PROCEDURE pr_inv_dev_mes;                                    -- sistemas

-- Inventario de Bonos Subordinados al cierre del Mes        -- finanzas
PROCEDURE pr_bonos_sub;

-- Inventarios de cartera activa y pasiva al cierre del Mes  -- finanzas
PROCEDURE pr_cartera_mes;

-- Inventario de Cuotas de Préstamos de los Clientes
PROCEDURE pr_cuo_pres_cli;                                   -- finanzas

-- Inventario de Cuotas de Préstamos Recibidos
PROCEDURE pr_cuo_pres_rec;                                   -- finanzas

-- Informe de pago de sueldos
PROCEDURE pr_pago_sueldo;                                    -- sistemas

/**************** FASE 2 ******************************/
-- Extracto de Funcionarios
PROCEDURE pr_ext_func;                                       -- extractos

-- Extracto Normales Retener
PROCEDURE pr_nor_retener;                                    -- extractos

-- Extracto Normales NO Retener
PROCEDURE pr_nor_no_reten;                                   -- extractos

-- Nomina Otras Sucursales
PROCEDURE pr_nomina_suc;                                     -- extractos

-- Nomina Sucursal 1 segun parametro recibido
PROCEDURE pr_nomina_suno
  (
    v_par1    VARCHAR2,
    v_par2    VARCHAR2
  );                                                         -- extractos

-- Procedimiento para obtener Nomina Sucursal 1 enviando parametros
PROCEDURE pr_obt_nomina;

-- Extracto Vip Retener
PROCEDURE pr_vip_retener;                                     -- extractos

-- Extracto Vip No Retener
PROCEDURE pr_vip_no_reten;                                    -- extractos

-- Extracto Vip Nomina
PROCEDURE pr_vip_nomina;                                      -- extractos

-- Extracto Premiun Retener
PROCEDURE pr_prem_retener;                                    -- extractos

-- Extracto Premiun No Retener
PROCEDURE pr_pre_no_reten;                                    -- extractos

-- Extracto Premiun Nomina
PROCEDURE pr_prem_nomina;                                     -- extractos

-- Extracto cliente confidencial
PROCEDURE pr_cli_confidencial;                                -- extractos

-- Procedimiento para ejecutar los procedimientos de extractos
PROCEDURE pr_ob_extractos;

-- Libro IVA de Compras Mensual
PROCEDURE pr_liva_compra;                                     -- contabilidad

-- Libro IVA de Ventas Mensual
PROCEDURE pr_liva_venta;                                      -- contabilidad

-- Archivos para Cidesa
PROCEDURE pr_arch_cidesa;                                     -- contabilidad

-- Archivos para Cidesa
PROCEDURE pr_arch_940_cidesa;


--Cuentas asociadas a Entes de Pago Salario
PROCEDURE pr_cta_aso_pag_sal;                                 -- operaciones

--Cuentas Nomina asociadas a Entes de Pago Salario
PROCEDURE pr_nom_pag_sal;                                     -- operaciones

-- Generación del plan de cuentas
PROCEDURE pr_gen_plan_cuentas;                                -- contabilidad

-- Saldos Promedios Abierto Diario
PROCEDURE pr_prom_abi_diario;                                 -- balances

-- Saldos Promedio Abierto por Sucursal - Diario
PROCEDURE pr_pro_abi_suc_diario;                              -- balances

-- Saldos Promedio Cerrado - Diario
PROCEDURE pr_prom_cer_diario;                                 -- balances

-- Saldos Promedio Cerrado por Sucursal - Diario
PROCEDURE pr_pro_cer_suc_diario;                              -- balances

-- Procedimiento para obtener reportes de saldos de promedio diarios
PROCEDURE pr_bal_prom_diario;

-- Informes para Casa Matriz en España - Renta Fija           -- contabilidad
PROCEDURE pr_info_renta_fija;

-- Generación de informe para cuadrar R1 del bcp diario       -- contabilidad
PROCEDURE pr_gen_inf_r1;

-- Generación de informe para cuadrar R1 del bcp mensual      -- contabilidad
PROCEDURE pr_gen_inf_r1_mens;

-- Generación de Mayor Contable                               -- contabilidad
PROCEDURE pr_gen_mayor(p_fec_desde in date,p_fec_hasta in date,p_rubro in varchar2,p_oficina in number);

--Inventario de Garantias
PROCEDURE pr_inv_gar;

--Inventario de Garantias(asientos contables)
PROCEDURE pr_inv_asi_gar;

--Inventario de Préstamos del Exterior
PROCEDURE pr_gen_pres_ext;                                     -- contabilidad

----------------------------------------------------------------------------------------------------------------------------------------
-- REPORTE DE CUADRE BALANCE GENERAL
--------------------------
PROCEDURE pr_cua_invcon;

----------------------------------------------------------------------------------------------------------------------------------------
-- REPORTE DE ENC_ASCII
--------------------------
PROCEDURE pr_enc_ascii;

--Inventario conciliación de tarjetas
PROCEDURE pr_con_automatica;

--------------------------------
-- CTAS TRANSITORIAS
--------------------------------
procedure pr_ctas_trnsitorias;

-- Informe diario de apuntes y asientos manuales
PROCEDURE pr_apu_masivos;
-- contabilidad

--Inventario de ventas con asientos y nro. de línea
PROCEDURE pr_lib_ventas1_det;

--Inventario de ventas con asientos y nro. de línea
PROCEDURE pr_lib_ventas3_det;

--Inventario de ventas con asientos y nro. de línea
PROCEDURE pr_lib_compras4_det;

--Generacion de movimientos de riesgos
PROCEDURE pr_gen_mov_riegos;

--Reporte de cuadre balance general - cuentas de resultado operativos
PROCEDURE pr_inv_resultado;

--Reporte de cuadre balance general - cuentas de resultado contable
PROCEDURE pr_inv_contable;

--Tiempos del cierre
PROCEDURE pr_tie_proc(p_cod_proceso ge_procesos_det.cod_proceso%type);

--Reporte de Análisis de liquidez1
PROCEDURE pr_analiq1;

--Reporte de Análisis de liquidez2
PROCEDURE pr_analiq2;

--Reporte de Análisis de liquidez3
PROCEDURE pr_analiq3;

--Reporte de Análisis de liquidez4
PROCEDURE pr_analiq4;

--Reporte de Análisis de liquidez5
PROCEDURE pr_analiq5;

--Reporte de Análisis de liquidez6
PROCEDURE pr_analiq6;
-- REPORTE CALCULO DE DEPOSITOS INTERNOS.
PROCEDURE pr_inv_dep_internos;

-- REPORTE SALDO PROMEDIOS DE BALANCE ANTES DE LA EJECUCION DEL PROCESOS DEPOSITOS INTERNOS.
PROCEDURE pr_sal_pro_di;

-- REPORTE DE VARIACION DE CARTERA (INVERSIÓN RENTABLE, ACTIVOS DUDOSOS Y RECURSOS).
PROCEDURE pr_inv_var_car;

-- REPORTE DE INVENTARIO DE VENTA DE CARTERA.
PROCEDURE pr_vta_cartera;

PROCEDURE pr_inf_ext;

-- Resumen de Cuentas de la Venta de Cartera.
PROCEDURE pr_inf_vta_cartera (P_REF_LOTE in ge_sal_inv_vta_cartera_his.ref_lote%type);

-- Informe del Proceso de Derrama de Gastos.
PROCEDURE pr_inf_der_gastos;

END pa_rep_aut;
/

