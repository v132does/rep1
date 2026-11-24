CREATE OR REPLACE FUNCTION IT.FUX_VER_COB_COMISION
 (p_nro_cuenta IN ge_cuentas.nro_cuenta%type,
  p_fec_inicio in date,
  p_cod_transaccion in number default null)
 RETURN VARCHAR2
 IS
v_encontro varchar2(1) := 'N';
--función que verifica si se cobró alguna comisión por la cuenta de comex
--cci, cce o cobranzas, desde el inicio de la cuenta
BEGIN
   select 'S'
     into v_encontro
     from gv_movimientos
    where cod_mod_padre = 8
      and cod_tra_padre = 150 --cobro de cargos
      and reversado = 'N'
      and referencia = p_nro_cuenta
      and cod_transaccion = nvl(p_cod_transaccion, cod_transaccion) --para transacción específica, mora x ej. 880
      and fecha >= p_fec_inicio;

   return v_encontro;
exception
   when too_many_rows then
      return 'S';
   when no_data_found then
      return 'N';
END;
/

