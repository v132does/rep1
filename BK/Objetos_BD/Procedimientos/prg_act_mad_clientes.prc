create or replace procedure it.prg_act_mad_clientes is

  v_hor_inicio varchar2(8);
  v_hor_fin    varchar2(8);
  v_fecha      date := sysdate;

  cursor prestamos is
    select c.nro_cuenta,
           c.nro_solicitud,
           c.cod_modalidad,
           c.cod_modulo,
           c.cod_moneda,
           b.cod_mad_destino
      from pr_cta_prestamos c, it.ge_cta_dat_fusion b
     where b.nro_cuenta = c.nro_cuenta
       and b.procesado = 'N'
       and c.cod_modulo = b.cod_modulo;

  type cursor1_type is table of prestamos%rowtype;
  reg cursor1_type;

  cursor ope_vencidas is
    select c.nro_cuenta,
           c.cod_modalidad,
           c.cod_modulo,
           c.cod_moneda,
           b.cod_mad_destino
      from ov_cta_vencidas c, it.ge_cta_dat_fusion b
     where b.nro_cuenta = c.nro_cuenta
       and b.procesado = 'N'
       and c.cod_modulo = b.cod_modulo;

  type cursor2_type is table of ope_vencidas%rowtype;
  reg2 cursor2_type;

  cursor mt_694 is
    select c.nro_cuenta,
           c.cod_modalidad,
           c.cod_modulo,
           c.cod_moneda,
           c.nro_solicitud,
           694 cod_mad_destino
      from pr_cta_prestamos c
     where c.nro_cuenta  in (3159914) ;

  type cursor3_type is table of mt_694%rowtype;
  reg3 cursor3_type;


  cursor mt_695 is
    select c.nro_cuenta,
           c.cod_modalidad,
           c.cod_modulo,
           c.cod_moneda,
           c.nro_solicitud,
           695 cod_mad_destino
      from pr_cta_prestamos c
     where c.nro_cuenta  in (2512464500020,2920688,2947355,2962064,2962697,2964071,
                             2972119,2972258,2973956,2974641,2979055,2980914,2988018,
                             2988049,2988943,2989542,2989734,2989803,2993960,2999656,
                             2999839,2999957) ;

  type cursor4_type is table of mt_695%rowtype;
  reg4 cursor4_type;

begin

  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  PAE_CNF.G_PROGRAMA   := 'GPPROFIN';

  open prestamos;
  loop
    fetch prestamos bulk collect
      into reg;
    for i in 1 .. reg.count loop

      begin
        update it.ge_movimientos
           set cod_modalidad = reg(i).cod_mad_destino
         where nro_cuenta = reg(i).nro_cuenta
           and cod_modulo = reg(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad :  ' ||
                                  SQLERRM|| reg(i).nro_cuenta );

      end;

      begin
        update it.pr_movimientos_his
           set cod_modalidad = reg(i).cod_mad_destino
         where nro_cuenta = reg(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;

      end;

      begin
        update it.pr_solicitudes
           set cod_modalidad     = reg(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_solicitud = reg(i).nro_solicitud
           and cod_modulo = reg(i).cod_modulo
           and cod_moneda = reg(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

      begin
        update it.pr_cta_prestamos
           set cod_modalidad     = reg(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg(i).nro_cuenta
           and cod_modulo = reg(i).cod_modulo
           and cod_moneda = reg(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad :  ' ||
                                  SQLERRM || reg(i).nro_cuenta);

      end;

      begin

        update it.ge_cuentas
           set cod_modalidad     = reg(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg(i).nro_cuenta
           and cod_modulo = reg(i).cod_modulo
           and cod_moneda = reg(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad :  '||reg(i).nro_cuenta ||
                                  SQLERRM);
      end;

      begin
        update it.ge_cta_clientes
           set cod_modalidad = reg(i).cod_mad_destino
         where nro_cuenta = reg(i).nro_cuenta
           and cod_modulo = reg(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_cta_clientes pr:  ' ||reg(i).nro_cuenta|| 
                                  SQLERRM);
      end;

      begin

        update it.pr_sal_mensuales
           set cod_modalidad = reg(i).cod_mad_destino
         where nro_cuenta = reg(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

    end loop;
    exit when prestamos%notfound;
  end loop;
  close prestamos;

  open ope_vencidas;
  loop
    fetch ope_vencidas bulk collect
      into reg2;
    for i in 1 .. reg2.count loop

      begin
        update it.ge_movimientos
           set cod_modalidad = reg2(i).cod_mad_destino
         where nro_cuenta = reg2(i).nro_cuenta
           and cod_modulo = reg2(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_movimientos ov_vencidas :  ' ||
                                  SQLERRM);

      end;

      begin
        update it.ov_movimientos_his
           set cod_modalidad = reg2(i).cod_mad_destino
         where nro_cuenta = reg2(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;

      end;

      begin
        update it.ov_cta_vencidas
           set cod_modalidad   = reg2(i).cod_mad_destino
         where nro_cuenta = reg2(i).nro_cuenta
           and cod_modulo = reg2(i).cod_modulo
           and cod_moneda = reg2(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ov_cta_vencidas:  ' ||
                                  SQLERRM);

      end;

      begin

        update it.ge_cuentas
           set cod_modalidad     = reg2(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg2(i).nro_cuenta
           and cod_modulo = reg2(i).cod_modulo
           and cod_moneda = reg2(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad :  ' ||
                                  SQLERRM);
      end;

      begin
        update it.ge_cta_clientes
           set cod_modalidad = reg2(i).cod_mad_destino
         where nro_cuenta = reg2(i).nro_cuenta
           and cod_modulo = reg2(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad :  ' ||
                                  SQLERRM);
      end;

      begin

        update it.ov_sal_mensuales
           set cod_modalidad = reg2(i).cod_mad_destino
         where nro_cuenta = reg2(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

    end loop;
    exit when ope_vencidas%notfound;
  end loop;
  close ope_vencidas;



 open mt_694;
  loop
    fetch mt_694 bulk collect
      into reg3;
    for i in 1 .. reg3.count loop

      begin
        update it.ge_movimientos
           set cod_modalidad = reg3(i).cod_mad_destino
         where nro_cuenta = reg3(i).nro_cuenta
           and cod_modulo = reg3(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad : MT_694 ' ||
                                  SQLERRM);

      end;

      begin
        update it.pr_movimientos_his
           set cod_modalidad = reg3(i).cod_mad_destino
         where nro_cuenta = reg3(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;

      end;

      begin
        update it.pr_solicitudes
           set cod_modalidad     = reg3(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_solicitud = reg3(i).nro_solicitud
           and cod_modulo = reg3(i).cod_modulo
           and cod_moneda = reg3(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

      begin
        update it.pr_cta_prestamos
           set cod_modalidad     = reg3(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg3(i).nro_cuenta
           and cod_modulo = reg3(i).cod_modulo
           and cod_moneda = reg3(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad pr_cta_prestamos mt694:  ' ||
                                  SQLERRM);

      end;

      begin

        update it.ge_cuentas
           set cod_modalidad     = reg3(i).cod_mad_destino,
               cod_sub_modalidad = 1
         where nro_cuenta = reg3(i).nro_cuenta
           and cod_modulo = reg3(i).cod_modulo
           and cod_moneda = reg3(i).cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_cuentas mt 694 :  ' ||
                                  SQLERRM);
      end;

      begin
        update it.ge_cta_clientes
           set cod_modalidad = reg3(i).cod_mad_destino
         where nro_cuenta = reg3(i).nro_cuenta
           and cod_modulo = reg3(i).cod_modulo;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al actualizar modalidad ge_cta_clientes pr: mt694  ' ||
                                  SQLERRM);
      end;

      begin

        update it.pr_sal_mensuales
           set cod_modalidad = reg3(i).cod_mad_destino
         where nro_cuenta = reg3(i).nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          null;
      end;

    end loop;
    exit when mt_694%notfound;
  end loop;
  close mt_694;


  open mt_695;
  loop
    fetch mt_695 bulk collect
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
    exit when mt_695%notfound;
  end loop;
  close mt_695;


end;
/
