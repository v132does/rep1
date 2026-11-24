CREATE OR REPLACE TRIGGER IT.TA_CX_CUOTAS
 AFTER DELETE OR UPDATE
 ON CX_CUOTAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE
v_nro_solicitud  cx_cuotas.nro_sol_prestamo%type;
v_nro_cuenta     cx_cuotas.nro_cta_prestamo%type;
v_existe varchar2(1);
BEGIN
   if updating then
      --si cambia la solicitud o cuenta de préstamo actualizar la CCI
      --sólo se da que se ingrese un valor al cobrar o se nule al reversar
      --sólo si ingresa valores actualizar la cci
      if :new.nro_sol_prestamo is not null then
         v_nro_solicitud := :new.nro_sol_prestamo;
      end if;
      if :new.nro_cta_prestamo is not null then
         v_nro_cuenta := :new.nro_cta_prestamo;
      end if;
      --actualizar cci
      begin
           select '*'
             into v_existe 
             from cx_cta_importaciones
             where nro_cuenta = :new.nro_cuenta;
      exception
         when others then
           null; --también se usa para cce y cobranzas
      end;
      if v_existe is not null then
         update cx_cta_importaciones
            set nro_sol_prestamo = nvl(v_nro_solicitud, nro_sol_prestamo)
          where nro_cuenta = :new.nro_cuenta;
      end if;
   end if;
END;
/

