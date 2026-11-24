create or replace package it.PAL_TRA is
/*Paquete para Transferncias internacionales via HB*/
/**  Obtiene la URL del ServiceIntegrator para DNA*/ 
g_dna_webservice VARCHAR2(150) := fug_obt_pardinamico('G_DNA_WEBSERVICE', NULL, NULL); --:= 'http://62.12.240.10:4802/ServiceIntegrator/notification/';
g_api_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_API'));
  
/** 
 * Funcion para verificar si una persona tiene gasto exonerado en los cargos
 */
FUNCTION FU_VER_GTO_EXONERADO
(
  p_cod_persona IN VARCHAR2
) RETURN VARCHAR2;

/**
 * Funcion para validar contrato de cambio para transferencias internacionales
 *
 * Retorno:
 * --------
 *  0: ok
 * -1: hora invalida
 * -2: contrato inexistente
 * -3: moneda invalida
 */
FUNCTION FU_VAL_CONTRATO
(
  p_cod_persona       IN ba_personas.cod_persona%TYPE,
  p_cod_mon_debito    IN ba_monedas.cod_moneda%TYPE,
  p_nro_contrato      IN lc_ope_pendientes.nro_diario%TYPE,
  p_cto_cod_moneda    OUT ba_monedas.cod_moneda%TYPE,
  p_cto_mto_cargo2    OUT NUMBER,
  p_cto_monto         OUT NUMBER,
  p_cto_tip_operacion OUT lc_tip_operaciones.cod_tip_operacion%TYPE
) RETURN NUMBER;

--Inserción de movimientos de transferencias internacionales via HB
PROCEDURE PR_INS_MOV_TRA_HB
(p_nro_cuenta       in varchar2 default null,
p_cod_mon_tra       in varchar2,     --Moneda Transferencia
p_plazo             in number,       --Plazo de La Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_nro_prepactada    in number default null, --Nro de Operación Pre-pactada
p_tip_cargo         in varchar2, --'OUR'/'BEN'
p_exonerado         in varchar2, -- 'S'/'N'
p_cotizacion        in number, --Cotización de Moneda de Transferencia
p_cot_contra        in number, --Cotización de Moneda de contra partida
p_es_noc            in varchar2:='N', --Si el movimiento es nocturno o No
p_nro_documento     out number, --Nro de Documento para el Movimiento
p_nro_documento2     out number, --Nro de Documento para el Movimiento
p_respuesta         out number, --Respuesta 0 sino hubo errores, sino Error
p_msj_error         out varchar2
);
--Obtiene totales de importe y cargos en la moneda de la cuenta
PROCEDURE PR_OBT_TOT_TRA_HB
(p_nro_cuenta       in varchar2 default null,
p_cod_mon_tra       in varchar2,     --Moneda Transferencia
p_plazo             in number,       --Plazo de La Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_nro_prepactada    in number default null, --Nro de Operación Pre-pactada
p_tip_cargo         in varchar2, --'OUR'/'BEN'
p_exonerado         in varchar2, -- 'S'/'N'
--Para intermediario
p_cod_bco_cor_contra  in lc_transferencias.cod_bco_cor_contra%type default null,
p_nom_bco_cor_contra  in lc_transferencias.nom_bco_cor_contra%type default null,
p_cod_swi_bco_contra  in lc_transferencias.cod_swi_bco_contra%type default null,
p_cod_pai_bco_contra  in lc_transferencias.cod_pai_bco_contra%type default null,
p_cod_ciu_bco_contra  in lc_transferencias.cod_ciu_bco_contra%type default null,
--
p_importe           out number, --Importe de la Operación
p_cargo             out number, --Importe del Cargo
p_cotizacion        out number, --Cotización de Moneda de Transferencia
p_cot_contra        out number, --Cotización de Moneda de contra partida
p_cod_tra_padre     out varchar2, --Transaccion Padre
p_fec_operacion     out date, --Fecha de Operación
p_fec_valor         out date, --Fecha de Valor
p_cod_tip_operacion out varchar2, -- codigo de operacion de venta/canje
p_respuesta         out number --Respuesta 0 sino hubo errores, sino Error
);
--Inserción de transacciones hb
PROCEDURE PR_INS_TRA_HB(
p_nro_referencia in lc_transferencias.nro_referencia%type,
p_nro_documento  in lc_transferencias.nro_operacion%type, --Nro de Doc del Mov./Nro de Ope.
p_cod_oficina in lc_transferencias.cod_oficina%type default null,
p_fec_operacion in lc_transferencias.fec_operacion%type default null,
p_cod_moneda in lc_transferencias.cod_moneda%type default null,
p_monto  in lc_transferencias.monto%type default null,
p_cod_banco  in lc_transferencias.cod_banco%type default null,
p_nom_banco  in lc_transferencias.nom_banco%type default null,
p_cod_pai_banco  in lc_transferencias.cod_pai_banco%type default null,
p_cod_ciu_banco  in lc_transferencias.cod_ciu_banco%type default null,
p_cod_aba_banco  in lc_transferencias.cod_aba_banco%type default null,
p_cod_swi_banco  in lc_transferencias.cod_swi_banco%type default null,
p_cod_per_solicitante  in lc_transferencias.cod_per_solicitante%type default null,
p_nom_solicitante  in lc_transferencias.nom_solicitante%type default null,
p_dir_solicitante  in lc_transferencias.dir_solicitante%type default null,
p_tel_solicitante  in lc_transferencias.tel_solicitante%type default null,
p_cod_pai_solicitante  in lc_transferencias.cod_pai_solicitante%type default null,
p_cod_ciu_solicitante  in lc_transferencias.cod_ciu_solicitante %type default null,
p_cod_per_beneficiario  in lc_transferencias.cod_per_beneficiario%type default null,
p_nom_beneficiario  in lc_transferencias.nom_beneficiario%type default null,
p_dir_beneficiario  in lc_transferencias.dir_beneficiario%type default null,
p_tel_beneficiario  in lc_transferencias.tel_beneficiario%type default null,
p_cod_pai_beneficiario  in lc_transferencias.cod_pai_beneficiario%type default null,
p_cod_ciu_beneficiario  in lc_transferencias.cod_ciu_beneficiario%type default null,
p_nro_cta_referencia  in lc_transferencias.nro_cta_referencia%type default null,
p_fec_recepcion  in lc_transferencias.fec_recepcion %type default null,
p_cod_rubro  in lc_transferencias.cod_rubro%type default null,
p_plazo  in lc_transferencias.plazo %type default null,
p_observacion  in lc_transferencias.observacion%type default null,
p_cod_uid_banco  in lc_transferencias.cod_uid_banco%type default null,
p_tip_cargo  in lc_transferencias.tip_cargo%type default null,
p_cod_bco_cor_contra  in lc_transferencias.cod_bco_cor_contra%type default null,
--Para intermediario
p_nom_bco_cor_contra  in lc_transferencias.nom_bco_cor_contra%type default null,
p_cod_swi_bco_contra  in lc_transferencias.cod_swi_bco_contra%type default null,
p_cod_pai_bco_contra  in lc_transferencias.cod_pai_bco_contra%type default null,
p_cod_ciu_bco_contra  in lc_transferencias.cod_ciu_bco_contra%type default null,
--
p_nom_ciu_beneficiario  in lc_transferencias.nom_ciu_beneficiario%type default null,
p_nom_ciu_solicitante  in lc_transferencias.nom_ciu_solicitante%type default null,
p_nro_doc_beneficiario  in lc_transferencias.nro_doc_beneficiario%type default null,
p_fec_valor  in lc_transferencias.fec_valor%type default null,
p_tip_fondo in lc_transferencias.tip_fondo%type default null,
p_tip_motivo in lc_transferencias.tip_fondo%type default null,
p_tip_financiacion in lc_transferencias.tip_fondo%type default null,
p_cod_tip_referencia lc_transferencias.cod_tip_referencia%type default null,
p_referencia  in lc_transferencias.referencia%type default null,
p_mto_cargo in lc_transferencias.mto_cargo%type default null,
p_nro_documento2 in lc_transferencias.Nro_Operacion2%type default null,
--DNA
p_nro_ord_pag_dna in lc_transferencias.nro_ord_pag_dna%type default null,
p_nro_cta_debito  in lc_transferencias.nro_cta_debito%type default null,
p_respuesta out number
);

FUNCTION FU_OBT_FEC_HABIL
 (P_FECHA IN DATE
 ,P_FACTOR IN NUMBER
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 )
 RETURN DATE;

/* Obtiene la Siguiente fecha habil */
FUNCTION FU_OBT_FEC_SIG_HAB
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_DIAS IN NUMBER DEFAULT 1
 )
 RETURN DATE;

--Validación de Transferencias Duplicadas en el útimo mes
FUNCTION FU_VAL_TRA_DUP
(
p_cod_mon_tra       in varchar2 default null, --Moneda Transferencia
p_monto             in number default null, --Monto de la Transferencia
p_cod_per_solicitante in number default null, --Cod.Persona Solicitante
p_nro_cta_referencia in varchar2 default null --Nro de Cuenta de Beneficiario
)
 RETURN number;

--Obtenemos el monto del contrato de cambios
FUNCTION FU_OBT_MTO_CONTRATO
(
p_nro_prepactada    in number,
p_cod_moneda        out ba_monedas.cod_moneda%type) --Nro de Operación Pre-pactada
 RETURN number;

--Consulta de Boletas de Ordenes de Pago DNA
PROCEDURE PR_CON_BOL_PAG_DNA
( p_nro_ord_pago        in varchar2 default null,   --Nro Orden de Pago DNA
  p_cod_mon_tte         in varchar2 default null,  --Moneda Origen TTE
  p_mto_tte             in number default null,    --Monto de Origen TTE
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento
  --Respuesta DNA
  p_cod_moneda          out varchar2, --Codigo de Moneda IT
  p_fecha               out date,     ----Fecha Creacion
  p_fec_vto             out date,     --Fecha Vencimiento
  p_tot_pagar           out number,   --Total a Pagar
  p_cotizacion          out number,   --Cotizacion DNA
  --  Respuesta de Servicio
  p_respuesta           out number, --respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2 --Mensaje de Error si Hubo
);


--Consulta de Operaciones DNA
PROCEDURE PR_CON_OPE_DNA
( p_nro_ord_pago        in varchar2 default null,  --Nro Orden de Pago DNA
  p_cod_mon_tte         in varchar2 default null,  --Moneda Origen TTE
  p_mto_tte             in number default null,    --Monto de Origen TTE
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento
  --Respuesta DNA
  p_tip_doc_pagador     out varchar2,  --Tipo de Documento IT
  p_nro_doc_pagador     out varchar2,  --Nro de Documento Pagador
  p_razon_social        out varchar2,  --Razon Social
  p_estado              out varchar2,  --Estado de la Operacion(ENC(En curso)/ANU(anulado)/VEN(vencimiento))
  p_fec_creacion        out date,      --Fecha de Creacion
  p_fec_vencimiento     out date,      --Fecha Vencimiento
  p_cod_mon_origen      out varchar2,  --Moneda Origen (IT)
  p_mto_origen          out number,    --Monto de Origen
  p_sal_origen          out number,    --Saldo de Origen
  -- Respuesta de Servicio
  p_respuesta           out number,    --Respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2   --Mensaje de Error si Hubo
);

--Inserci¿n de Registros de Transferencias enviadas a DNA
PROCEDURE PR_ENV_REG_TRA_DNA
( p_nro_referencia      in number default null,   --Nro referencia IT
  p_cod_tip_referencia  in varchar2 default null, --cod_tip_referencia IT
  p_nro_ref_externa     in varchar2 default null,
  --Respuesta de Servicio
  p_respuesta           out number, --respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2 --Mensaje de Error si Hubo
);

--Reversion de Ordenes de Pago DNA
PROCEDURE PR_REV_DNA
( p_id_operacion        in varchar2 default null,   --Id operacion DNA
  p_nro_documento       in varchar2 default null,  --Nro de Documento
  p_tip_documento       in varchar2 default null,  --Tipo de Documento
  p_observacion         in varchar2 default null, -- Motivo de la reversa
  --Respuesta de Servicio
  p_respuesta           out number, --respuesta 0 sino hubo errores, sino error
  p_msj_error           out varchar2 --Mensaje de Error si Hubo
);

/**
 * Validar Banco, pais y ciudad
 * 0: ok
 * -9: banco invalido
 * -10: pais invalido
 * -11: ciudad invalida
 */
FUNCTION FU_VAL_BANCO
( p_cod_banco  IN ge_bancos.cod_banco%TYPE DEFAULT NULL,
  p_cod_pais   IN ba_paises.cod_pais%TYPE DEFAULT NULL,
  p_cod_ciudad IN ba_ciudades.cod_ciudad%TYPE DEFAULT NULL
) RETURN NUMBER;

/**
 * Validar Banco Corresponsal, pais y ciudad
 * 0: ok
 * -8: banco invalido
 * -12: pais invalido
 * -13: ciudad invalida
 */
FUNCTION FU_VAL_BCO_CORRESPONSAL
( p_cod_bco_cor_contra IN ge_bancos.cod_banco%TYPE DEFAULT NULL,
  p_cod_pai_bco_contra   IN ba_paises.cod_pais%TYPE DEFAULT NULL,
  p_cod_ciu_bco_contra IN ba_ciudades.cod_ciudad%TYPE DEFAULT NULL
) RETURN NUMBER;

end PAL_TRA;
/

