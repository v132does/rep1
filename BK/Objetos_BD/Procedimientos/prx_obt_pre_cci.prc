CREATE OR REPLACE PROCEDURE IT.PRX_OBT_PRE_CCI
 (P_NRO_CUENTA IN CX_CTA_IMPORTACIONES.NRO_CUENTA%TYPE,
 p_nro_cuota in cx_cuotas.nro_cuota%type default null,
 P_CANCELADA IN VARCHAR2 default 'N',
 p_nro_sol_prestamo out number,
 p_nro_cta_prestamo out varchar2)
 IS

/*obtine los datos de préstamos asociados a la cci*/
Begin
    if p_nro_cuota is not null then
      --busca que sea la máxima cuota pagada contra préstamo
     select nro_sol_prestamo, nro_cta_prestamo
       into p_nro_sol_prestamo, p_nro_cta_prestamo
       from cx_cuotas a
      where estado = 'P' --(decode(p_cancelada,'S','P',estado))
        and (nro_sol_prestamo is not null or nro_cta_prestamo is not null)
        and nro_cuenta = p_nro_cuenta
        and nro_cuota = p_nro_cuota
        and nro_cuota = (select max(nro_cuota)
                          from cx_Cuotas b
                          where a.estado = 'P'--(decode(p_cancelada,'S','P',estado))
                          and (nro_sol_prestamo is not null or nro_cta_prestamo is not null)
                          and a.nro_Cuenta = b.nro_cuenta);
    else 
      --busca en la cci
     select nro_sol_prestamo
       into p_nro_sol_prestamo
       from cx_cta_importaciones
      where --estado = 'G'--(decode(p_cancelada,'S','G',estado)) --sin estado xq se reversa primero el estado
        --and 
        (nro_sol_prestamo is not null)
        and nro_cuenta = p_nro_cuenta;
    end if;

exception
   when no_data_found then
      p_nro_sol_prestamo:=null;
      p_nro_cta_prestamo:=null;
--      raise_application_error(-20000,'No existe prést. relacionado. CCI.'||p_nro_cuenta||' Cuo.'||p_nro_cuota);
   when others then
      raise_application_error(-20000,'Error al recuperar prést. relacionado.'||sqlerrm);
End;
/

