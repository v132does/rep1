create or replace procedure it.pra_cob_car_uso_otr_atm
 (p_nro_cuenta in varchar2 default null) is

  V_COD_TAS_CARGO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO  GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO  GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO      GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_car_mas_iva       number(18,2);

  v_hor_actual        varchar2(08) ;
  v_fec_actual        date;
  v_nro_secuencia     number(3) := 0;
   v_nvo_estado        varchar2(1);
  v_sal_disponible    number;
  v_procesa           varchar2(1);
begin
 null;
end;
/

