declare

  cursor prestamos is
    select c.nro_cuenta,
           c.cod_modalidad,
           c.cod_modulo,
           c.cod_moneda,
           c.nro_solicitud,
           970 cod_mad_destino
      from pr_cta_prestamos c
     where c.nro_cuenta  in (2512464500020,2920688,2947355,2962064,2962697,2964071,
                             2972119,2972258,2973956,2974641,2979055,2980914,2988018,
                             2988049,2988943,2989542,2989734,2989803,2993960,2999656,
                             2999839,2999957) ;

  type cursor4_type is table of prestamos%rowtype;
  reg4 cursor4_type;

begin

  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  PAE_CNF.G_PROGRAMA   := 'GPPROFIN';



  open prestamos;
  loop
    fetch prestamos bulk collect
      into reg4;
    for i in 1 .. reg4.count loop

      begin
        update it.ge_movimientos
           set cod_modalidad = reg4(i).cod_mad_destino
         where nro_cuenta = reg4(i).nro_cuenta
           and cod_modulo = reg4(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_movimientos : MT_694 ' ||
                                  SQLERRM);

      end;

      begin
        update it.pr_movimientos_his
           set cod_modalidad = reg4(i).cod_mad_destino
         where nro_cuenta = reg4(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;

      end;

      begin
        update it.pr_solicitudes
           set cod_modalidad     = reg4(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_solicitud = reg4(i).nro_solicitud
           and cod_modulo = reg4(i).cod_modulo
           and cod_moneda = reg4(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

      begin
        update it.pr_cta_prestamos
           set cod_modalidad     = reg4(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg4(i).nro_cuenta
           and cod_modulo = reg4(i).cod_modulo
           and cod_moneda = reg4(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad pr_cta_prestamos mt 695 :  ' ||
                                  SQLERRM);

      end;

      begin

        update it.ge_cuentas
           set cod_modalidad     = reg4(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg4(i).nro_cuenta
           and cod_modulo = reg4(i).cod_modulo
           and cod_moneda = reg4(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad  ge_cuentas mt 695:  ' ||
                                  SQLERRM);
      end;

      begin
        update it.ge_cta_clientes
           set cod_modalidad = reg4(i).cod_mad_destino
         where nro_cuenta = reg4(i).nro_cuenta
           and cod_modulo = reg4(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_cta_clientes pr mt 695:  ' ||
                                  SQLERRM);
      end;

      begin

        update it.pr_sal_mensuales
           set cod_modalidad = reg4(i).cod_mad_destino
         where nro_cuenta = reg4(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

    end loop;
    exit when prestamos%notfound;
  end loop;
  close prestamos;

commit;
end;
