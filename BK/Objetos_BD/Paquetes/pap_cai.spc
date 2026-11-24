CREATE OR REPLACE PACKAGE IT.PAP_CAI IS

v_mon_local ba_monedas.cod_moneda%type;
v_mon_fuerte ba_monedas.cod_moneda%type;
v_cot_mon_fuerte ge_cotizaciones.val_conversion%type;
v_tot_deuda number(18);
v_tipo_clie ge_clientes.tipo%type;
v_lugar varchar2(4000);
v_fec_proceso date;

/* verificar si un cliente es de sólo consumo. */
function fu_cli_solo_consumo
 (p_cod_clie in ge_clientes.cod_persona%type
 )
 return varchar2;
/* verificar si un cliente es de sólo vivienda. */
function fu_cli_solo_vivienda
 (p_cod_clie in ge_clientes.cod_persona%type
 )
 return varchar2;
/* convertir un monto a guaraníes. */
function fu_con_a_guaranies
 (p_cod_moneda in ba_monedas.cod_moneda%type
 ,p_monto in pr_cta_prestamos.mto_capital%type
 )
 return number;
/* obtener la categoría que le corresponde x mora. */
function fu_obt_categ_x_mora
 (p_can_dias in number
 )
 return number;
/* proceso principal de categorización según la resolución 37. */
procedure pr_pro_cat_res37;
/* procesar categorización de clientes. */
procedure pr_pro_cat_clientes;
/* procesar categorización de grupos económicos. */
procedure pr_pro_cat_gru_econ;
/* proceso de categorización de préstamos. */
procedure pr_pro_dat_prestamo;
/* procesar categorización de operaciones vencidas */
procedure pr_pro_dat_ope_ven;
/* insertar datos en la tabla ge_cla_incobrables. */
procedure pr_ins_ge_cla_inc
 (rp_oper in ge_cla_operaciones%rowtype
 );

/* verifica si el cliente está relacionado con la entidad. */
function fu_ver_cli_rel_enti
 (p_cod_persona in varchar2
 )
 return boolean;

/* solo para rrr, se verifica la forma de pago de la nueva operación */
procedure pr_obt_for_pag_rrr
 (p_nro_cuenta in ge_cuentas.nro_cuenta%type,
  p_fec_ult_categorizacion in pr_cta_prestamos.fec_ult_categorizacion%type,
  p_pue_categoria in out varchar2,  --- puede mejorar categoría s/n
  p_pue_prevision in out varchar2, --- puede liberar previsión s/n
  p_cat_mejorada  out    varchar2);
/* verifica si el grupo económico tiene más de un cliente. */
function fu_ver_gru_mas_clie
 (p_cod_gru_economico in ge_gru_economicos.cod_gru_economico%type
 )
 return boolean;

END PAP_CAI;
/

