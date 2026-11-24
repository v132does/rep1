CREATE OR REPLACE FUNCTION IT.FUE_OBT_TRA_INTERES
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
   P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE,
   P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODULO%TYPE
 )

 RETURN VARCHAR2
 IS
-- Esta Funcion retorna S o N, segun la transaccion sume o no para interes
   v_esinteres varchar2(1) := 'N';
   v_cantidad number(18):=0;
Begin

begin  
select decode(nvl(count(*),0),0,'N','S') 
  into v_esinteres
   from ge_transacciones x
    where x.cod_transaccion = p_cod_transaccion
       and x.cod_modulo = p_cod_modulo
       and x.cod_modalidad =  p_cod_modalidad
       and exists (
          select 1
            from ge_tip_asientos a 
             where (a.cod_rubro like ('61010%') or a.cod_rubro like ('61020%') or
                    a.cod_rubro like ('61030%') or  a.cod_rubro like ('61070%'))
                    and x.cod_tip_asiento = a.cod_tip_asiento);
exception
   when no_data_found then
     v_esinteres:='N';
    when too_many_rows then
     v_esinteres:='S' ; 
    when others then 
      v_esinteres:='N' ;
end;
       
IF v_esinteres= 'N' THEN     
  begin
  select decode(nvl(count(*),0),0,'N','S')
   into v_esinteres
    from ge_transacciones x
      where x.cod_transaccion = p_cod_transaccion
          and x.cod_modulo = p_cod_modulo
          and x.cod_modalidad =  p_cod_modalidad
          and exists (
            select 1
               from ge_tip_asientos a 
                 where (a.cod_rubro like ('61010%') or a.cod_rubro like ('61020%') or
                        a.cod_rubro like ('61030%') or  a.cod_rubro like ('61070%'))
                        and x.cod_tip_asiento2 = a.cod_tip_asiento);
  exception
     when no_data_found then
        v_esinteres:='N';
      when too_many_rows then
        v_esinteres:='S' ; 
      when others then 
        v_esinteres:='N' ;
  end;
END IF;
   
   Return v_esinteres;
exception
   when others then
      return 'N';
End;
/

