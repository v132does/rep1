CREATE OR REPLACE PROCEDURE IT.PRJ_VER_CAJ_CERRADA
 IS
  v_cantidad   number(10);
  v_fec_actual ge_calendarios.fec_actual%type;
  v_nro_caj_hbank ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('NRO_CAJ_HBANK');
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(9);
   select count(*)
     into v_cantidad
     from cj_controles c
    where estado <> 2
      and fecha <= v_fec_actual
      and instr(v_nro_caj_hbank,','||c.nro_caja||',') = 0;
   if v_cantidad > 0 then
      raise_application_error(-20000,
      'Existen cajas sin cerrarse, verifique');
   end if;
END;
/

