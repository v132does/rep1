create or replace function it.FUG_IMP_TRANSACCION
(P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
) 
  return varchar2 is
--verifica si la combinación de transaccion se imprime en el comprobante 
begin
  /*
  --DYDMR-13672 NAF 2020-09-24 se comenta para permitir impresion del comprobante
  if p_cod_tra_padre = 556 and p_cod_modalidad = 41 and p_cod_transaccion = p_cod_tra_padre then 
     return 'N';
  els
  */
  if p_cod_tra_padre = 132 and p_cod_modalidad = 41 and p_cod_transaccion = 602 then     	
     return 'N';
  elsif p_cod_tra_padre = 515 and p_cod_modalidad in (31,41) and p_cod_transaccion = p_cod_tra_padre then
     return 'N';
  else
     return 'S';
  end if;
exception
  when others then
    return 'S';
end FUG_IMP_TRANSACCION;
/

