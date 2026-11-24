CREATE OR REPLACE FUNCTION IT.fug_obt_tip_iva_prestamo(p_nro_solicitud  IN pr_solicitudes.nro_solicitud%TYPE)
  RETURN VARCHAR2 IS
  v_tip_iva    varchar2(100);
  v_tiene      varchar2(1):='N';
BEGIN

  begin
   Select 'S'
     into v_tiene
       FROM PR_SOL_CARGOS b
         where b.nro_solicitud= p_nro_solicitud
          and b.cod_transaccion=709;
  exception
    when no_data_found then
      v_tiene:='N';
    when too_many_rows then
      v_tiene:='S';
    when others then
      v_tiene:='N';
  end ;

  if v_tiene ='S' then
     v_tip_iva:= 'IVA ADELANTADO';
  else
    v_tip_iva:= 'IVA CUOTIZADO';
  end if;

RETURN v_tip_iva;

END;
/

