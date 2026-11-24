create or replace package body it.paa_dex is
--https://itti-digital.atlassian.net/browse/NVB-3811
  g_mod_estado    ba_modulos.estado%TYPE;
  /*Verificar horario*/
   procedure lp_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_modulo         in ba_modulos.cod_modulo%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out number,
                           p_men_error      out varchar2) is

    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error  := 0;
    p_horario    := 'D'; -- dia normal
    p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(p_modulo);--obtiene estado del módulo

    if v_est_modulo in (1,6) then
        p_cod_error := '1070';
        p_men_error := 'Modulo en proceso de cierre';
    elsif v_est_modulo = 2 then
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    else --(3,4)
          p_horario := 'N'; -- noche
          if v_est_modulo <> 1 then
            p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                     1,
                                                     p_cod_ofi_origen);
          end if;
          p_es_mov_noc := 'S'; -- para grabar en las tablas nocturnas
          p_es_cta_noc := 'S'; -- solo para que llavee la cuenta nocturna
    end if;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    g_mod_estado      := v_est_modulo;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_men_error := 'Ocurrio un error en la verificacion de horario';
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.LP_VER_HORARIO',
                            substr(DBMS_UTILITY.format_error_backtrace || ' ' ||
                                   DBMS_UTILITY.format_error_stack,
                                   1,
                                   4000),
                            null,
                            null);

  END lp_ver_horario;
   /*procedimiento para obtener datos de la persona*/
  procedure pr_obt_val_dat_cliente(p_tip_documento   in number,
                                   p_nro_documento   in varchar2,
                                   p_fec_nacimiento  in date,
                                   p_telefono        in varchar2,
                                   p_tip_operacion   in varchar2, -- D=Deposito / E=Extraccion
                                   p_nro_cta_credito in out number,
                                   p_cod_persona     out varchar2,
                                   p_nombres         out varchar2,
                                   p_apellidos       out varchar2,
                                   p_cod_error       out number,
                                   p_msj_error       out varchar2) is
    v_tip_persona    varchar2(1);
    v_existe         number;
    v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
    v_telefono       varchar2(20);
    v_cod_mon_cta    ge_cuentas.cod_moneda%type;
    v_est_cta        varchar2(1);
    v_des_estado     ge_est_cuentas.descripcion%type;
    v_pri_nombre     ba_per_fisicas.pri_nombre%type;
    v_seg_nombre     ba_per_fisicas.seg_nombre%type;
    v_pri_apellido   ba_per_fisicas.pri_apellido%type;
    v_seg_apellido   ba_per_fisicas.seg_apellido%type;
    v_tip_documento  ba_personas.cod_tip_documento%type;
    v_nro_documento  ba_personas.nro_documento%type;
    v_tip_doc_cta    ba_personas.cod_tip_documento%type;
    v_nro_doc_cta    ba_personas.nro_documento%type;
    v_cod_persona    ba_personas.cod_persona%type;
  Begin
    v_tip_documento := p_tip_documento;
    v_nro_documento := p_nro_documento;

    If nvl(upper(p_tip_operacion), 'X') not in ('E', 'D') Then
      If p_tip_operacion is null Then
        p_cod_error := 1;
        p_msj_error := 'Debe ingresar un tipo de operacion';
        return;
      Else
        p_cod_error := 2;
        p_msj_error := 'Los tipos de operacion aceptados son E-Extraccion / D-Deposito';
        return;
      End if;
    End if;

    If nvl(upper(p_tip_operacion), 'X') = 'E' Then

      If p_fec_nacimiento is null Then
        p_cod_error := 3;
        p_msj_error := 'La fecha de nacimiento no puede ser nulo ';
        return;
      End if;

      If nvl(p_telefono, 'X') = 'X' Then
        p_cod_error := 4;
        p_msj_error := 'El nro de celular no puede ser nulo ';
        return;
      End if;

      If v_tip_documento is null Then
        p_cod_error := 5;
        p_msj_error := 'Debe ingresar el tipo de documento';
        return;
      End if;

      If v_nro_documento is null Then
        p_cod_error := 6;
        p_msj_error := 'Debe ingresar el nro de documento';
        return;
      End if;

    End if;

    --Si la cuenta credito es nulo se debe ingresar el tipo de documento y nro de documento
    If nvl(upper(p_tip_operacion), 'X') = 'D' Then

      If p_nro_cta_credito is not null Then

        Begin
          select t.estado, t.cod_moneda, ec.descripcion
            into v_est_cta, v_cod_mon_cta, v_des_estado
            from ge_cuentas t, ge_est_cuentas ec
           where t.nro_cuenta = p_nro_cta_credito
             and t.cod_modulo = ec.cod_modulo
             and t.cod_modalidad = ec.cod_modalidad
             and t.estado = ec.estado;
        Exception
          when no_data_found then
            v_est_cta     := null;
            v_cod_mon_cta := null;
            v_des_estado  := null;
            p_cod_error   := 7;
            p_msj_error   := 'No se encuentra el numero de cuenta ingresado';
          when others then
            v_est_cta     := null;
            v_cod_mon_cta := null;
            v_des_estado  := null;
            p_cod_error   := 8;
            p_msj_error   := 'Error al recuperar datos de la cuenta ' ||
                             sqlerrm;
        End;

        If nvl(v_est_cta, 'X') not in ('A', 'N', 'D','S', 'I') Then
          p_cod_error := 9;
          p_msj_error := 'La cuenta ingresada se encuentra en estado ' ||
                         v_des_estado;
          return;
        End if;

        If v_cod_mon_cta != pag_gen.FU_OBT_MON_LOCAL Then
          p_cod_error := 10;
          p_msj_error := 'La cuenta ingresada no esta en moneda Guaranies';
          return;
        End if;

        Begin
          select p.cod_tip_documento, p.nro_documento
            into v_tip_doc_cta, v_nro_doc_cta
            from ge_cta_clientes t, ba_personas p
           where t.nro_cuenta = p_nro_cta_credito
             and t.relacion = 'P'
             and t.cod_persona = p.cod_persona;
        Exception
          when no_data_found then
            v_tip_doc_cta := null;
            v_nro_doc_cta := null;
            p_cod_error   := 11;
            p_msj_error   := 'No se encuentra la persona titular de la cuenta ingresada';
          when others then
            v_tip_doc_cta := null;
            v_nro_doc_cta := null;
            p_cod_error   := 12;
            p_msj_error   := 'Error al recuperar datos de la persona relacionada a la cuenta ' ||
                             sqlerrm;
        End;

        If (v_tip_documento is null or v_nro_documento is null) Then

          v_tip_documento := v_tip_doc_cta;
          v_nro_documento := v_nro_doc_cta;

        Else
          If v_tip_doc_cta != v_tip_documento Then
            p_cod_error := 13;
            p_msj_error := 'El tipo de documento ingresado no corresponde al titular de la cuenta';
            return;
          End if;

          If v_nro_doc_cta != v_nro_documento Then
            p_cod_error := 14;
            p_msj_error := 'El nro de documento ingresado no correponde al titular de la cuenta';
            return;
          End if;
        End if;
      Else
        If v_tip_documento is null Then
          p_cod_error := 15;
          p_msj_error := 'Debe ingresar el tipo de documento';
          return;
        End if;

        If v_nro_documento is null Then
          p_cod_error := 16;
          p_msj_error := 'Debe ingresar el nro de documento';
          return;
        End if;
      End if;
    End If;

    If (v_tip_documento is not null and v_nro_documento is not null) then

      Begin
        select p.tipo
          into v_tip_persona
          from ba_personas p
         where p.nro_documento = v_nro_documento
           and p.cod_tip_documento = v_tip_documento;
      Exception
        when no_data_found then
          --no se encontro datos los parametros especificos, buscar solo por numero de documento
          begin
            select count(1)
              into v_existe
              from ba_personas p
             where p.nro_documento = trim(v_nro_documento);
            if nvl(v_existe, 0) = 1 then
              p_cod_error := 17;
              p_msj_error := 'Tipo de documento ingresado es incorrecto';
            elsif nvl(v_existe, 0) > 1 then
              p_cod_error := 18;
              p_msj_error := 'Error al recuperar datos de la persona. Existe mas de un registro.';
            elsif nvl(v_existe, 0) = 0 then
              p_cod_error := 19;
              p_msj_error := 'Persona no registrada en el sistema';
            end if;
          exception
            when no_data_found then
              p_cod_error := 20;
              p_msj_error := 'Persona no registrada en el sistema';
          end;
        when too_many_rows then
          v_tip_persona := null;
          p_cod_error   := 21;
          p_msj_error   := 'Error al recuperar datos de la persona. Existen datos similares.';
      End;

      If nvl(p_cod_error, 0) = 0 Then

        If nvl(v_tip_persona, 'X') = 'F' Then
          -- persona fisica
          Begin
            Select p.cod_persona,
                   f.pri_nombre,
                   f.seg_nombre,
                   f.pri_apellido,
                   f.seg_apellido,
                   f.fec_nacimiento,
                   t.area || t.telefono telefono_principal
              Into v_cod_persona,
                   v_pri_nombre,
                   v_seg_nombre,
                   v_pri_apellido,
                   v_seg_apellido,
                   v_fec_nacimiento,
                   v_telefono
              From ba_personas p, ba_per_fisicas f, ba_telefonos t
             Where p.cod_persona = f.cod_persona
               and p.cod_persona = t.cod_persona(+)
               and t.principal(+) = 'S'
               and p.cod_tip_documento = v_tip_documento
               and p.nro_documento = v_nro_documento;

            p_cod_persona := v_cod_persona;
            p_nombres     := v_pri_nombre || ' ' || v_seg_nombre;
            p_apellidos   := v_pri_apellido || ' ' || v_seg_apellido;
            p_cod_error   := 0;
          Exception
            When too_many_rows then
              v_fec_nacimiento := null;
              v_telefono       := null;
              p_cod_error      := 22;
              p_msj_error      := 'Error al recuperar datos de la persona. Existe mas de un registro';
            When others then
              v_fec_nacimiento := null;
              v_telefono       := null;
              p_cod_error      := 23;
              p_msj_error      := 'Error al recuperar datos de la persona ' ||
                                  sqlerrm;
          End;

          If nvl(p_cod_error, 0) = 0 Then
            --Valida que la fecha de nacimiento corresponda a la persona
            If nvl(upper(p_tip_operacion), 'X') = 'E' Then

              If p_fec_nacimiento != v_fec_nacimiento Then
                p_cod_error   := 24;
                p_msj_error   := 'Fecha de nacimiento : ' ||
                                 p_fec_nacimiento ||
                                 ' no corresponde a la persona';
                p_nombres     := null;
                p_apellidos   := null;
                p_cod_persona := null;
                return;
              End if;
              --Valida numero de celular
              If p_telefono != v_telefono Then
                p_cod_error   := 25;
                p_msj_error   := 'El numero de celular ' || p_telefono ||
                                 ' no corresponde a la persona';
                p_nombres     := null;
                p_apellidos   := null;
                p_cod_persona := null;
                return;
              End if;

            End if;

          End if;

        Elsif nvl(v_tip_persona, 'X') = 'J' Then

          p_cod_error   := 26;
          p_msj_error   := 'La persona ingresada es una persona juridica y no puede realizar operaciones';
          p_nombres     := null;
          p_apellidos   := null;
          p_cod_persona := null;
          return;

        End if;

      End if;

    End if;

    If nvl(p_cod_error, 0) = 0 Then
      p_cod_error := 0;
      p_msj_error := 'Los datos son correctos';
    End if;

  Exception
    When Others Then
      p_cod_error := 16;
      p_msj_error := sqlerrm;
  end pr_obt_val_dat_cliente;
  /*procedimiento para validar saldo cliente*/
  procedure pr_val_sal_mov_cliente(p_nro_cuenta    in varchar2,
                                   p_monto         in number, --monto operacion
                                   p_moneda        in varchar2, ----Solo GS
                                   p_tip_operacion in varchar2, -- D=Deposito / E=Extraccion
                                   p_mto_total_gs  out number, --Total GS(monto operacion+monto movimiento)
                                   p_mto_limite    out number, --Mto limite establecido en parametro gral
                                   p_error         out number,
                                   p_respuesta     out varchar2) is

    v_mto_limite        ge_movimientos.monto%type:=null;
    v_cod_moneda        ba_monedas.cod_moneda%type;
    v_mon_cta           ba_monedas.cod_moneda%type;
    v_mto_tot_gs_diario ge_movimientos.monto%type := 0;
    v_cod_tra_padre     ge_transacciones.cod_transaccion%type;
    v_cod_transaccion   ge_transacciones.cod_transaccion%type;
    v_nom_par_gral      ge_parametros.parametro%type;
    v_can_ope           number(3):=0;
    v_par_can_ope       ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PAR_CAN_OPE_DEP_PRO');
    cursor c_movimientos is
      select m.monto, m.cod_moneda
        from ge_movimientos m
       where m.cod_tra_padre = v_cod_tra_padre
         and m.cod_transaccion = v_cod_transaccion
         and m.nro_cuenta = p_nro_cuenta
         and m.reversado = 'N';
  begin
    /*Proceso para el control de exceso de movimientos por cuenta*/
    /*Validaciones*/
    p_error := 0;
    p_respuesta := 'OK';
    if nvl(p_monto, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Debe ingresar el monto de la operacion: ';
      return;
    end if;
    if nvl(p_moneda, 'x') = 'x' then
      p_error     := 2;
      p_respuesta := 'Debe ingresar la moneda';
      return;
    end if;
    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'El numero de cuenta no puede ser nulo';
      return;
    end if;
    if nvl(p_tip_operacion, 'x') = 'x' then
      p_error     := 5;
      p_respuesta := 'Tipo de operacion no puede ser nulo';
      return;
    end if;
    v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    v_mon_cta := pag_cta.G_CTAS.cod_moneda;
    if v_mon_cta != p_moneda then
      p_error     := 6;
      p_respuesta := 'La moneda de la operacion no corresponde a la moneda de la cuenta';
      return;
    end if;
    /*Extracciones*/
    if p_tip_operacion = 'E' then
      v_nom_par_gral    := 'LIM_MTO_DIA_EXT_GRAL_PRO';
      v_cod_transaccion := 9730;
      v_cod_tra_padre   := 8906;
      /*Depositos*/
    elsif p_tip_operacion = 'D' then
      v_nom_par_gral    := 'LIM_MTO_DIA_DEP_GRAL_PRO';
      v_cod_transaccion := 9729;
      v_cod_tra_padre   := 8906;
    else
      p_error     := 7;
      p_respuesta := 'Tipo operacion incorrecto - ' || p_tip_operacion;
      return;
    end if;

    if v_mto_limite is null then
      /*busca el monto limite general por tipo de operacion */
      v_mto_limite := to_number(fug_obt_pardinamico(v_nom_par_gral,
                                                    null,
                                                    null,
                                                    v_cod_moneda));
    end if;
    for reg in c_movimientos loop
      if reg.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
        if p_tip_operacion = 'D' then
           v_can_ope := v_can_ope + 1;
        end if;
        v_mto_tot_gs_diario := v_mto_tot_gs_diario + reg.monto;
      end if;
    end loop;
    if v_mto_limite is not null or v_par_can_ope is not null then
      if nvl(v_mto_tot_gs_diario, 0) + p_monto > nvl(v_mto_limite,0) then
        p_error     := 10;
        p_respuesta := 'NOK-Monto supera el limite diario';
      elsif p_tip_operacion = 'D' and v_can_ope + 1 > nvl(v_par_can_ope,0) then
        p_error     := 10;
        p_respuesta := 'NOK-Cantidad supera el limite diario';
      else
        p_error     := 0;
        p_respuesta := 'OK';
      end if;
    end if;
    p_mto_total_gs := nvl(v_mto_tot_gs_diario, 0) + p_monto;
    p_mto_limite   := nvl(v_mto_limite, 0);
  exception
    when others then
      p_error     := 12;
      p_respuesta := 'NOK - ' || SQLERRM;
  end pr_val_sal_mov_cliente;
  /*procedimiento para validar saldo extracciones*/
  procedure pr_val_sal_extracciones(p_nro_cuenta     in varchar2,
                                    p_monto          in number,
                                    p_moneda         in varchar2, --solo GS
                                    p_respuesta      out varchar2,
                                    p_error          out number,
                                    p_sal_disponible out number) is

    /*Proceso que verifica si la cuenta tiene saldo suficiente para la extraccion*/
    v_est_cuenta     ge_cuentas.estado%type;
    v_sal_disponible ge_movimientos.monto%type;
    v_procesa        varchar2(1) := 'N';
    v_cod_modulo     ge_movimientos.cod_modulo%type := NULL;
    v_cod_modalidad  ge_movimientos.cod_modalidad%type := NULL;
    v_cod_moneda     ba_monedas.cod_moneda%type;
    v_mon_final      ge_movimientos.monto%type;
    v_est_cta        varchar2(1);
    v_des_estado     ge_est_cuentas.descripcion%type;

  begin
    p_error              := 0;
    pae_cnf.g_cod_modulo := 1;
    v_cod_moneda         := p_moneda;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);

    /*verifica si la cuenta es conjunta*/
    if fu_es_conjunta(p_nro_cuenta) = 'S' then
      p_error     := 1;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;

    /*verifica estado de la cuenta*/
    Begin
      select t.estado, ec.descripcion
        into v_est_cta, v_des_estado
        from ge_cuentas t, ge_est_cuentas ec
       where t.nro_cuenta = p_nro_cuenta
         and t.cod_modulo = ec.cod_modulo
         and t.cod_modalidad = ec.cod_modalidad
         and t.estado = ec.estado;
    Exception
      when no_data_found then
        p_error     := 2;
        p_respuesta := 'No se encuentra el numero de cuenta ingresado';
      when others then
        p_error     := 3;
        p_respuesta := 'Error al recuperar datos de la cuenta ' || sqlerrm;
    End;

    If nvl(v_est_cta, 'X') not in ('I', 'N', 'S') Then --estado inactiva, normal, bloqueo saldo
      p_error     := 4;
      p_respuesta := 'La cuenta ingresada se encuentra en estado ' ||
                     v_des_estado;
      return;
    End if;
    /*Validar monto*/
    if nvl(p_monto, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Debe ingresar el monto de la operacion: ';
      return;
    end if;

    /*verificar el saldo disponible*/
    v_mon_final := nvl(p_monto, 0);
    pag_cta.PR_VER_OPERACION(p_nro_cuenta,
                             8906,
                             pag_cta.G_CTAS.COD_MODULO,
                             pag_cta.G_CTAS.COD_MODALIDAD,
                             'D',
                             v_cod_moneda,
                             v_mon_final,
                             pag_cta.G_CTAS.COD_OFICINA,
                             v_cod_modulo,
                             v_cod_modalidad,
                             v_est_cuenta,
                             v_sal_disponible,
                             v_procesa,
                             9730); --8908

    if v_procesa = 'N' then
      p_error          := 5;
      p_respuesta      := pag_cta.G_MSJ_ERROR;
      p_sal_disponible := v_sal_disponible;
    elsif v_procesa = 'S' then
      p_respuesta      := 'OK';
      p_sal_disponible := v_sal_disponible;
    end if;
  exception
    when others then
      p_respuesta := 'NOK- ' || SQLERRM;
      p_error     := 6;
  end pr_val_sal_extracciones;
  /*procedimiento para generar pin aleatorio*/
  procedure pr_gen_pin_alea_extracciones(p_cod_persona in varchar2,
                                         p_nro_celular in varchar2,
                                         p_error       out number,
                                         p_respuesta   out varchar2,
                                         p_pin         out number) is
    /*Verifica si el nro.celular corresponde a la persona y genera un numero aleatorio de 4 digitos*/
    v_existe     varchar2(1) := 'N';
    v_existe_per varchar2(1) := null;

  begin
    v_existe     := 'N';
    v_existe_per := null;
    begin
      select 'S'
        into v_existe
        from ba_telefonos t
       where t.cod_persona = p_cod_persona
         and t.tip_linea = 'C'
         and (t.telefono = p_nro_celular OR
             t.area || t.telefono = p_nro_celular)
         --and t.tipo = 'P';
         and t.Principal='S';
    exception
      when NO_DATA_FOUND then
        p_error     := 1;
        p_respuesta := 'El numero ' || p_nro_celular ||
                       ' no corresponde a la persona';
        return;
    end;
    begin
      begin
        /*si no existe cod persona,inserta datos*/
        select 'S'
          into v_existe_per
          from ge_pin_aleatorio a
         where a.cod_persona = p_cod_persona;
      exception
        when NO_DATA_FOUND then
          if v_existe = 'S' then
            p_error     := 0;
            p_respuesta := 'OK';
            p_pin       := round(dbms_random.value(1000, 9999), 0);
            begin
              insert into ge_pin_aleatorio
                (cod_persona, nro_pin, nro_celular, est_pin, intentos)
              values
                (p_cod_persona, p_pin, p_nro_celular, 'P', 0);
              commit;
            exception
              when others then
                p_error     := 2;
                p_respuesta := sqlerrm;
            end;
          end if;
      end;
      /*si ya existe cod persona, actualiza datos*/
      if v_existe = 'S' then
        p_error     := 0;
        p_respuesta := 'OK';
        if v_existe_per = 'S' then
          p_pin       := round(dbms_random.value(1000, 9999), 0);
          begin
            update ge_pin_aleatorio
               set nro_pin     = p_pin,
                   nro_celular = p_nro_celular,
                   est_pin     = 'P',
                   intentos    = 0
             where cod_persona = p_cod_persona;
            commit;
          exception
            when others then
              p_error     := 3;
              p_respuesta := sqlerrm;
          end;
        end if;
      end if;
    end;
  exception
    when others then
      p_error     := 4;
      p_respuesta := 'NOK- ' || sqlerrm;
  end pr_gen_pin_alea_extracciones;
  /*procedimiento para validar pin aleatorio*/
  procedure pr_val_pin_alea_extracciones(p_cod_persona in varchar2,
                                         p_pin         in number,
                                         p_est_actual  out varchar2,
                                         p_error       out number,
                                         p_respuesta   out varchar2) is
    /*Valida pin para extraccion*/
    v_cantidad number := 0;
    cantidad   number;
    cursor val_pin is
      select cod_persona, nro_pin, est_pin, intentos
        from ge_pin_aleatorio
       where cod_persona = p_cod_persona;
  begin
    for reg in val_pin loop
      cantidad   := reg.intentos;
      v_cantidad := cantidad + 1;
      /*numero de pin corresponde*/
      if reg.cod_persona = p_cod_persona and reg.nro_pin = p_pin and
         reg.est_pin = 'P' and cantidad in (0,1,2,3) then
        p_error      := 0;
        p_est_actual := 'A';
        p_respuesta  := 'OK';
        /*numero de pin activo */
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin = p_pin and
            reg.est_pin = 'A' and cantidad in (0,1,2,3)then
        p_error      := 1;
        p_est_actual := 'A';
        p_respuesta  := 'PIN Activo';
        /*numero de pin no corresponde */
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin != p_pin and
            reg.est_pin = 'P' and v_cantidad in (0,1,2,3) then
        p_error      := 2;
        p_est_actual := 'P';
        p_respuesta  := 'Numero de PIN no corresponde';
        /*supero la cantidad de intentos permitidos*/
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin != p_pin and
            reg.est_pin = 'P' and v_cantidad > 3 then
        p_error      := 3;
        p_est_actual := 'I';
        p_respuesta  := 'Se supero la cantidad de intentos permitidos';
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin != p_pin and
            reg.est_pin = 'I' then
        p_error      := 4;
        p_est_actual := 'I';
        p_respuesta  := 'El numero de PIN se encuentra Inactivo';
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin = p_pin and
            reg.est_pin = 'I' then
        p_error      := 5;
        p_est_actual := 'I';
        p_respuesta  := 'El numero de PIN se encuentra Inactivo';
      end if;
    end loop;
  exception
    when others then
      p_error     := 6;
      p_respuesta := 'NOK- ' || sqlerrm;
  end pr_val_pin_alea_extracciones;
  /*procedimiento para generar movimiento depositos*/
  procedure pr_gen_mov_deposito(p_monto      in number,
                                p_nro_cuenta in varchar2, --cuenta cliente credito
                                p_cod_moneda in varchar2, --solo GS
                                p_mov_id     out varchar2, --Movimiento_id
                                p_fecha      out varchar2, --Fecha
                                p_cta_nro    out varchar2, --Cta numero
                                p_titular    out varchar2, --Nombre completo Titular Cta
                                p_moneda     out varchar2, --Moneda
                                p_tot_dep    out varchar2, --Total depositado
                                p_cod_error  out number,
                                p_msj_error  out varchar2) is
    --VARIABLE
    v_par_ente            ge_par_entes.val_parametro%type;
    v_cuenta              ge_movimientos.nro_cuenta%type := p_nro_cuenta;
    v_cuenta_pronet       ge_movimientos.nro_cuenta%type;
    v_moneda              ba_monedas.cod_moneda%type;
    v_mto                 ge_movimientos.monto%type := p_monto;
    v_fecha_actual        DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_hora                ge_movimientos.hora%TYPE;
    v_nro_documento       ge_movimientos.nro_documento%type;
    v_nro_secuencia       ge_movimientos.nro_secuencia%type := 0;
    v_referencia          ge_movimientos.referencia%type;
    v_cod_persona         ba_personas.cod_persona%type;
    v_tip_valor           ge_tasas.tip_valor%type;
    v_cod_transaccion     ge_movimientos.cod_transaccion%TYPE DEFAULT NULL;
    v_det_error           ge_log_errores.det_error%type;
    v_ofi_cta_ahorro      ba_oficinas.cod_oficina%type;
    v_mto_equ_local       ge_movimientos.mto_equ_local%type := null;
    v_cod_tasa_pronet     ge_tasas.cod_tasa%type;
    v_fecha_vig           ge_tas_fechas.fec_vigencia%TYPE;
    v_tipo_tasa           ge_tasas.tipo%TYPE;
    v_valor_com           ge_movimientos.monto%type;
    v_comision            ge_movimientos.monto%type;
    v_codigo_modulo       NUMBER(3) := 4;
    v_codigo_modalidad    NUMBER(3) := 43;
    v_tra_comision        NUMBER(4);
    v_mon_cre             ge_movimientos.monto%type;
    v_cod_ente            ge_entes.cod_ente%type := fug_obt_pardinamico('COD_ENT_PRONET');
    v_moda_cuenta         number(3); --(modalidad)
    v_tasa_pronet         ge_par_entes.val_parametro%type;
    v_tope_com            ge_par_entes.val_parametro%type;
    v_tope_com_max        NUMBER;
    v_cod_tra_padre       ge_transacciones.cod_transaccion%type;
    v_cod_transaccion_deb NUMBER(4);
    v_titular             ba_personas.nom_completo%type;
    v_tip_doc             ba_personas.cod_tip_documento%type;
    v_nro_doc_per         ba_personas.nro_documento%type;
    v_usuario             varchar2(15);
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);
  begin
    select S_NRO_DOCU_PRONET.nextval into v_nro_documento from dual;
    p_cod_error := 0;
    p_msj_error := 'OK';
    if nvl(p_monto, 0) = 0 then
      if p_monto is null then
        p_cod_error := 1;
        p_msj_error := 'El monto de la operacion no puede ser nulo ';
        return;
      else
        p_cod_error := 1;
        p_msj_error := 'Debe ingresar el monto de la operacion mayor a cero ';
        return;
      end if;
    end if;
    if p_nro_cuenta is null then
      p_cod_error := 2;
      p_msj_error := 'El numero de cuenta no puede ser nulo';
      return;
    end if;
    if nvl(p_cod_moneda, 'x') != 'GS' then
      p_cod_error := 3;
      p_msj_error := 'Debe ingresar la moneda GS';
      return;
    end if;

    v_referencia := v_nro_documento;
    v_moneda     := it.pag_gen.fu_obt_mon_local;
    -- obtenemos la cuenta rubro
    if v_moneda = it.pag_gen.fu_obt_mon_local then
      v_par_ente := 'CTA_OP_PRONET_DEP_GS';
    end if;

    /*obtiene cuenta operativa deposito pronet*/
    v_cuenta_pronet := it.fug_obt_parentes(v_cod_ente, v_par_ente);
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
   
    --recupera datos del cliente
    v_cod_persona := fug_obt_cli_principal(v_cuenta);
    select t.nom_completo, t.cod_tip_documento, t.nro_documento
      into v_titular, v_tip_doc, v_nro_doc_per
      from ba_personas t
     where t.cod_persona = v_cod_persona;
    savepoint deposito;
    if NVL(p_cod_error, 0) = 0 then
      pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
      v_ofi_cta_ahorro := pag_cta.g_ctas.cod_oficina;
      begin
        select cod_modalidad
          into v_moda_cuenta
          from ge_cuentas a
         where a.nro_cuenta = p_nro_cuenta;
      exception
        when no_data_found then
          p_cod_error := 3;
          p_msj_error := 'No se encuentra cta de ahorro';
          rollback to deposito;
        when others then
          p_cod_error := 3;
          p_msj_error := 'No se encuentra cta de ahorro';
          rollback to deposito;
      end;
      if v_moda_cuenta not in (31, 334, 41) then
        p_cod_error := 4;
        p_msj_error := 'Tipo de cuenta no permite operaciones';
        rollback to deposito;
      end if;
      v_cod_tra_padre       := 8906; --transaccion padre
      v_cod_transaccion_deb := 8907;
      v_cod_transaccion     := 9729; --Transaccion para deposito pronet
      v_tra_comision        := 8909; --transaccion comision pronet
      if nvl(p_cod_error, 0) = 0 then
        --Verifica estado del modulo
        lp_ver_horario(v_ofi_cta_ahorro,
                     '3',
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                    v_fecha_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
                     
      if nvl(v_error, 0) = 0 then
        begin
          --generar, debito cuenta operativa
          --v_hora          := fug_obt_mov_hora;
          v_nro_secuencia := v_nro_secuencia;
          PAG_CTA.PR_SET_REFERENCIA(v_referencia);
          pag_cta.pr_set_nro_documento3(v_cod_ente);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          /*se agrega rotacion de usuarios para no generar error de pk en ge_movimientos*/
          v_usuario := fu_obt_mov_usuario('APIPRONET');
          v_hora := fu_obt_hora(v_usuario);
          pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_codigo_modulo,
                                   p_cod_mad_padre  => v_codigo_modalidad);
          pag_cta.pr_act_operacion(v_cuenta_pronet,
                                   v_hora,
                                   'D',
                                   v_moneda,
                                   v_mto,
                                   v_cod_tra_padre,
                                   v_cod_transaccion_deb,
                                   v_nro_documento,
                                   null,
                                   v_ofi_cta_ahorro,
                                   4,
                                   43,
                                   null,
                                   null,
                                   'DEBITO POR DEPOSITOS EN PRONET ' ||
                                   v_cuenta_pronet,
                                   'N',
                                   v_nro_secuencia,
                                   v_fecha_actual,
                                   null,
                                   null,
                                   v_mto_equ_local);
          if pag_cta.G_COD_ERROR != 0 then
            p_cod_error := 10;
            p_msj_error := pag_cta.G_MSJ_ERROR;
            rollback to deposito;
            -----------------------------------------------------------------------------------------------
          else
            v_tasa_pronet     := 'TASA_COMISION_PRONET';
            v_cod_tasa_pronet := it.fug_obt_parentes(v_cod_ente,
                                                     v_tasa_pronet);
            if v_cod_tasa_pronet is not null then
              -- Si tiene configurado tasa para comision, entonces generar movimiento por comision e IVA
              --Valor de tasa
              pag_gen.pr_obt_val_tasa(4,
                                      43,
                                      v_ofi_cta_ahorro,
                                      null,
                                      v_moneda,
                                      null,
                                      null,
                                      v_cod_tasa_pronet,
                                      null,
                                      null,
                                      v_valor_com,
                                      v_fecha_vig,
                                      v_tip_valor,
                                      v_tipo_tasa);
              IF v_tip_valor = 'P' THEN
                -- procentaje
                v_comision := round(p_monto * v_valor_com / 100, 0);
              ELSE
                -- valor --
                v_comision := v_valor_com;
              END IF;
              --validar tope comision establecido
              v_tope_com     := 'TOPE_MONTO_COMISION_PRONET';
              v_tope_com_max := it.fug_obt_parentes(v_cod_ente, v_tope_com);
              if v_comision > v_tope_com_max then
                v_comision := v_tope_com_max;
              end if;
              v_mon_cre := p_monto;
            end if;
            --generar credito de comision en cta. operativa
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.pr_set_nro_documento3(v_cod_ente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
             pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_codigo_modulo,
                                   p_cod_mad_padre  => v_codigo_modalidad);
            pag_cta.pr_act_operacion(v_cuenta_pronet,
                                     v_hora,
                                     'C',
                                     v_moneda,
                                     v_comision,
                                     v_cod_tra_padre,
                                     v_tra_comision,
                                     v_nro_documento,
                                     null,
                                     v_ofi_cta_ahorro,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'CREDITO POR COMISIONES PRONET DEPOSITOS ' ||
                                     v_cuenta_pronet,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
            if pag_cta.G_COD_ERROR != 0 then
              p_cod_error := 111;
              p_msj_error := 'Error crédito cta: '||v_cuenta_pronet||' - '||pag_cta.G_MSJ_ERROR;
              rollback to deposito;
            -----------------------------------------------------------------------------------------------
            end if;
            --generar credito en cta. cliente
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.pr_set_nro_documento3(v_cod_ente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
             pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_codigo_modulo,
                                   p_cod_mad_padre  => v_codigo_modalidad);
            pag_cta.pr_act_operacion(v_cuenta,
                                     v_hora,
                                     'C',
                                     v_moneda,
                                     v_mon_cre,
                                     v_cod_tra_padre,
                                     v_cod_transaccion,
                                     v_nro_documento,
                                     null,
                                     v_ofi_cta_ahorro,
                                     4,
                                     43,
                                     null,
                                     null,
                                     'CREDITO POR DEPOSITO PRONET ' ||
                                     v_cuenta,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
             if pag_cta.G_COD_ERROR != 0 then
              p_cod_error := 112;
              p_msj_error := 'Error crédito cta: '||v_cuenta||' - '||pag_cta.G_MSJ_ERROR;
              rollback to deposito;
            -----------------------------------------------------------------------------------------------
            end if;
            ---------------------------------------------------------------------------------------------------
          end if;
        exception
          when others then
            p_cod_error := 5;
            p_msj_error := 'Error el proceso de cobro ' || sqlerrm;
            rollback to deposito;
        end;

      else 
         p_cod_error := v_error;
         p_msj_error :=v_respuesta;
      end if;
      end if;
      
        p_mov_id    := v_nro_documento;
        p_fecha     := v_fecha_actual;
        p_cta_nro   := v_cuenta;
        p_titular   := v_titular;
        p_moneda    := v_moneda;
        p_tot_dep   := v_mto;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Ente: ' || v_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Fecha ' || p_fecha || ' Monto: ' || p_monto || ' ' ||
                     p_cod_moneda || ' Error: Cod. ' || p_cod_error || '-' ||
                     p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_MOV_DEPOSITO',
                            v_det_error,
                            null,
                            p_nro_cuenta);
    end if;
  exception
    when others then
      p_cod_error := 7;
      p_msj_error := sqlerrm;
      v_det_error := 'Ente: ' || v_cod_ente || ' ID mov: ' || p_mov_id ||
                     ' Fecha ' || p_fecha || ' Monto: ' || p_monto || ' ' ||
                     p_cod_moneda || ' Error: Cod. ' || p_cod_error || '-' ||
                     p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_MOV_DEPOSITO',
                            v_det_error,
                            null,
                            p_nro_cuenta);
  end pr_gen_mov_deposito;
  /*procedimiento para generar movimiento extracciones*/
  procedure pr_gen_mov_extraccion(p_nro_cuenta  in varchar2, --cuenta cliente
                                  p_moneda      in varchar2, --GS
                                  p_monto       in number, --monto extraccion
                                  p_cod_persona in varchar2,
                                  p_mov_id      out varchar2, --Movimiento_id
                                  p_fecha       out varchar2, --Fecha
                                  p_cta_nro     out varchar2, --Cta numero
                                  p_moneda_cta  out varchar2, --Moneda
                                  p_total_ext   out number, --Total extraccion
                                  p_nom_per     out varchar2,
                                  p_tip_doc_per out varchar2,
                                  p_nro_doc_per out varchar2,
                                  p_error       out number,
                                  p_respuesta   out varchar2) is

    /*Variables*/
    v_cod_tra_padre   ge_transacciones.cod_transaccion%type;
    v_cod_transaccion ge_transacciones.cod_transaccion%type;
    v_cod_moneda      ba_monedas.cod_moneda%type;
    v_hor_actual      VARCHAR2(08);
    v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(5);
    v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
    v_cta_cre_ente    ge_par_entes.val_parametro%type;
    v_par_ente        ge_par_entes.val_parametro%type;
    v_cod_mod_ente    ge_cta_clientes.cod_modulo%type;
    v_cod_mad_ente    ge_cta_clientes.cod_modalidad%type;
    v_cod_mon_cta     ba_monedas.cod_moneda%type;
    v_tip_valor       ge_tasas.tip_valor%TYPE;
    v_tra_comsion     ge_transacciones.cod_transaccion%type;
    v_det_error       ge_log_errores.det_error%type;
    v_cod_ofi_origen  ge_movimientos.cod_ofi_origen%type;
    v_mto_equ_local   ge_movimientos.mto_equ_local%type;
    v_cod_persona     ba_personas.cod_persona%type := fug_obt_cli_principal(p_nro_cuenta);
    v_moneda          ba_monedas.cod_moneda%type;
    v_nro_documento   ge_movimientos.nro_documento%type;
    v_tasa_pronet     ge_par_entes.val_parametro%type;
    v_cod_tasa_pronet ge_tasas.cod_tasa%type;
    v_valor_com       ge_tas_rangos.val_tasa%type; -- ge_movimientos.monto%type;
    v_fecha_vig       ge_tas_fechas.fec_vigencia%TYPE;
    v_tipo_tasa       ge_tasas.tipo%TYPE;
    v_titular         ba_personas.nom_completo%type;
    v_tip_doc         ba_tip_documentos.abreviatura%type;
    v_nro_doc_per     ba_personas.nro_documento%type;
    v_tope_com        ge_par_entes.val_parametro%type;
    v_tope_com_max    ge_movimientos.monto%type;
    v_tope_mon        ge_par_entes.val_parametro%type;
    v_tope_mon_ext    ge_movimientos.monto%type;
    V_FEC_FINAL       DATE;
    v_cod_ente        ge_entes.cod_ente%type := fug_obt_pardinamico('COD_ENT_PRONET');
    v_err_ext_supera  exception;
    v_usuario             varchar2(15);
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);
  begin
    select S_NRO_DOCU_PRONET.nextval into v_nro_documento from dual;
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if p_nro_cuenta is null then
      p_error     := 1;
      p_respuesta := 'El numero de cuenta no puede ser nulo';
      return;
    end if;
    if nvl(p_moneda, 'x') != 'GS' then
      p_error     := 2;
      p_respuesta := 'Debe ingresar la moneda GS';
      return;
    end if;
    if nvl(p_monto, 0) = 0 then
      if p_monto is null then
        p_error     := 1;
        p_respuesta := 'El monto de la operacion no puede ser nulo ';
        return;
      else
        p_error     := 3;
        p_respuesta := 'Debe ingresar el monto de la operacion mayor a cero ';
        return;
      end if;
    end if;
    if p_cod_persona is null then
      p_error     := 4;
      p_respuesta := 'El codigo de persona no puede ser nulo ';
      return;
    end if;
    --v_cod_persona:= fug_obt_cli_principal(p_nro_cuenta);
    v_cod_ofi_origen  := fug_obt_ofi_usuario(USER);
    v_cod_tra_padre   := 8906; --Transaccion padre
    v_cod_transaccion := 9730; --Transaccion para extraccion pronet
    v_tra_comsion     := 8910; --Transaccion para comision de extraccion pronet
    v_cod_moneda      := pag_gen.FU_OBT_MON_LOCAL;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    v_cod_mon_cta := pag_cta.G_CTAS.cod_moneda;

    /*La moneda de la extraccion debe ser igual a la moneda de la cuenta*/
    if v_cod_mon_cta != v_cod_moneda then
      p_error     := 6;
      p_respuesta := 'La moneda de la operacion no corresponde a la moneda de la cuenta';
      return;
    end if;
    if fu_es_conjunta(p_nro_cuenta) = 'S' then
      p_error     := 7;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;
    --recupera datos del cliente
    if p_cod_persona is not null then
      begin
        select t.nom_completo, t.nro_documento, u.abreviatura
          into v_titular, v_nro_doc_per, v_tip_doc
          from ba_personas t, ba_tip_documentos u
         where t.cod_persona = p_cod_persona
           and t.cod_tip_documento = u.cod_tip_documento;
      exception
        when no_data_found then
          p_error     := 5;
          p_respuesta := 'Codigo de persona ingresado no existe';
      end;
    end if;
    /*Recupera los datos del ente*/
    v_moneda := pag_gen.FU_OBT_MON_LOCAL;
    -- obtenemos la cuenta rubro
    if v_moneda = it.pag_gen.fu_obt_mon_local then
      v_par_ente := 'CTA_OP_PRONET_EXT_GS';
    end if;

    /*obtiene cuenta operativa extraccion pronet*/
    v_cta_cre_ente := fug_obt_parentes(v_cod_ente, v_par_ente);
    if v_cta_cre_ente is null then
      p_error     := 8;
      p_respuesta := 'La cuenta en la moneda ' || v_cod_moneda ||
                     ' del ente ' || v_cod_ente ||
                     ' no se encuentra configurada';
      return;
    end if;
    pag_cta.PR_OBT_CUENTA(v_cta_cre_ente);
    if pag_cta.G_COD_ERROR = 0 then
      v_cod_mod_ente := pag_cta.G_CTAS.cod_modulo;
      v_cod_mad_ente := pag_cta.G_CTAS.cod_modalidad;
    else
      p_error     := 9;
      p_respuesta := pag_cta.G_MSJ_ERROR;
      return;
    end if;
    --Verifica estado del modulo
        lp_ver_horario(v_cod_ofi_origen,
                     '3',
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                     v_fec_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
                     
    if nvl(v_error, 0) = 0 then
      begin
        savepoint extraccion;
        v_tope_com        := 'TOPE_MONTO_EXT_PRONET';
        v_tope_com_max    := it.fug_obt_parentes(v_cod_ente, v_tope_com);
        v_tope_mon        := 'MONTO_EXT_TOPE';
        v_tope_mon_ext    := it.fug_obt_parentes(v_cod_ente, v_tope_mon);
        if p_monto <= v_tope_mon_ext then
          --v_hor_actual := fug_obt_mov_hora;
          /*genera Debito al cliente*/
          pag_cta.pr_set_referencia(v_nro_documento);
          pag_cta.pr_set_nro_documento3(v_cod_ente);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
             /*se agrega rotacion de usuarios para no generar error de pk en ge_movimientos*/
          v_usuario := fu_obt_mov_usuario('APIPRONET');
          v_hor_actual := fu_obt_hora(v_usuario);
          pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_cod_mod_ente,
                                   p_cod_mad_padre  => v_cod_mad_ente);
          pag_cta.PR_ACT_OPERACION(p_nro_cuenta,
                                   v_hor_actual,
                                   'D',
                                   v_cod_moneda,
                                   p_monto,
                                   v_cod_tra_padre,
                                   v_cod_transaccion,
                                   v_nro_documento,
                                   null,
                                   v_cod_ofi_origen,
                                   v_cod_mod_ente,
                                   v_cod_mad_ente,
                                   null,
                                   null,
                                   'DEBITO POR EXTRACCION POR PRONET' ||
                                   p_nro_cuenta,
                                   'N',
                                   v_nro_secuencia,
                                   v_fec_actual,
                                   null,
                                   null,
                                   v_mto_equ_local);
          if pag_cta.G_COD_ERROR != 00 then
            p_error     := 12;
            p_respuesta := pag_cta.G_MSJ_ERROR;
           rollback to extraccion;
          else
            /*genera credito a la cuenta operativa pronet*/
            pag_cta.pr_set_referencia(v_nro_documento);
            pag_cta.pr_set_nro_documento3(v_cod_ente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_cod_mod_ente,
                                   p_cod_mad_padre  => v_cod_mad_ente);
            pag_cta.pr_act_operacion(v_cta_cre_ente,
                                     v_hor_actual,
                                     'C',
                                     v_cod_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     8908,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_origen,
                                     v_cod_mod_ente,
                                     v_cod_mad_ente,
                                     null,
                                     null,
                                     'CREDITO POR EXTRACCION PRONET' ||
                                     v_cta_cre_ente,
                                     'N',
                                     v_nro_secuencia,
                                     v_fec_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
            if pag_cta.G_COD_ERROR != 00 then
              p_error     := 12;
              p_respuesta := pag_cta.G_MSJ_ERROR;
             rollback to extraccion;
            else
            --obtiene valor tasa comision de extraccion
            v_tasa_pronet     := 'TASA_COMISION_EXT_PRONET';
            v_cod_tasa_pronet := it.fug_obt_parentes(v_cod_ente,
                                                     v_tasa_pronet);
            if v_cod_tasa_pronet is not null and p_monto > v_tope_mon_ext then
              v_valor_com := v_tope_com_max;
            elsif v_cod_tasa_pronet is not null and p_monto <= v_tope_mon_ext then
              pag_gen.pr_obt_val_tasa(4,
                                      43,
                                      v_cod_ofi_origen,
                                      null,
                                      v_moneda,
                                      p_monto,
                                      null,
                                      v_cod_tasa_pronet,
                                      NULL,
                                      V_FEC_FINAL,
                                      v_valor_com,
                                      v_fecha_vig,
                                      v_tip_valor,
                                      v_tipo_tasa);
            end if;
            pag_cta.pr_set_referencia(v_nro_documento);
            pag_cta.pr_set_nro_documento3(v_cod_ente);
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                   p_fec_valor      => trunc(sysdate),
                                   p_cod_tra_padre  => v_cod_tra_padre,
                                   p_estado         => 'N',
                                   p_reversado      => 'N',
                                   p_nro_secuencia  => v_nro_secuencia,
                                   p_est_cuenta     => null,
                                   p_cod_ofi_origen => 61,
                                   p_cod_mod_padre  => v_cod_mod_ente,
                                   p_cod_mad_padre  => v_cod_mad_ente);
            pag_cta.pr_act_operacion(v_cta_cre_ente,
                                     v_hor_actual,
                                     'C',
                                     v_cod_moneda,
                                     v_valor_com,
                                     v_cod_tra_padre,
                                     v_tra_comsion,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_origen,
                                     v_cod_mod_ente,
                                     v_cod_mad_ente,
                                     v_cod_tasa_pronet,
                                     v_valor_com,
                                     'CREDITO POR COMISION EXTRACCION PRONET',
                                     'N',
                                     v_nro_secuencia,
                                     v_fec_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
           end if;                          
          end if;
        else
          raise v_err_ext_supera;
        end if;
      exception
        when v_err_ext_supera then
             p_error     := 15;
             p_respuesta := 'Supera monto de extraccion. Maximo: '||v_tope_mon_ext;
             v_det_error := 'Ente: ' || v_cod_ente || ' ID mov: ' ||
                            v_nro_documento || ' Monto: ' || p_monto || ' ' ||
                            p_moneda || ' Error: Cod. ' || p_error || '-' ||
                            p_respuesta;
             PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_MOV_EXTRACCION',
                    v_det_error,
                    v_cod_persona,
                    p_nro_cuenta);
        when others then
          p_error     := 16;
          p_respuesta := sqlerrm;
        rollback to extraccion;
      end;
       else 
         p_error := v_error;
         p_respuesta :=v_respuesta;
       end if;

    if nvl(p_error, 0) = 0 then
      p_mov_id      := v_nro_documento;
      p_fecha       := v_fec_actual;
      p_cta_nro     := p_nro_cuenta;
      p_nom_per     := v_titular;
      p_moneda_cta  := v_cod_mon_cta;
      p_total_ext   := p_monto;
      p_error       := 0;
      p_tip_doc_per := v_tip_doc;
      p_nro_doc_per := v_nro_doc_per;
      p_respuesta   := 'OK';
    else
      v_det_error := 'Ente: ' || v_cod_ente || ' ID mov: ' ||
                     v_nro_documento || ' Monto: ' || p_monto || ' ' ||
                     p_moneda || ' Error: Cod. ' || p_error || '-' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_MOV_EXTRACCION',
                            v_det_error,
                            v_cod_persona,
                            p_nro_cuenta);
    end if;

  exception
    when others then
      p_error     := 18;
      p_respuesta := 'NOK - ' || SQLERRM;
      v_det_error := 'Ente: ' || v_cod_ente || ' ID mov: ' ||
                     v_nro_documento || ' Monto: ' || p_monto || ' ' ||
                     p_moneda || ' Error: Cod. ' || p_error || '-' ||
                     p_respuesta;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_MOV_EXTRACCION',
                            v_det_error,
                            v_cod_persona,
                            p_nro_cuenta);
  end pr_gen_mov_extraccion;
  /*procedimiento para reversar movimiento deposito-extraccion*/
  procedure pr_gen_rev_operacion(p_mov_id    in varchar2,
                                 p_cod_error out number,
                                 p_msj_error out varchar2) is

    v_fecha         ge_movimientos.fecha%type;
    v_hora          ge_movimientos.hora%type;
    v_usuario       ge_movimientos.cod_usuario%type;
    v_cod_mod_padre ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
    v_existe        varchar2(1);
    v_det_error     ge_log_errores.det_error%type;
    v_nro_documento ge_movimientos.nro_documento%type;
    v_concepto      ge_movimientos.concepto%type;
    v_rev_hora      ge_movimientos.hor_reversion%type;
    v_rev_usuario   ba_usuarios.cod_usuario%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    begin
      select 'S',
             t.fecha,
             t.hora,
             t.cod_usuario,
             t.cod_mod_padre,
             t.cod_mad_padre,
             t.cod_tra_padre,
             t.nro_documento,
             t.concepto
        into v_existe,
             v_fecha,
             v_hora,
             v_usuario,
             v_cod_mod_padre,
             v_cod_mad_padre,
             v_cod_tra_padre,
             v_nro_documento,
             v_concepto
        from ge_movimientos t
       where t.reversado = 'N'
         and rownum = 1
         and t.referencia = p_mov_id;
    exception
      when no_data_found then
        v_existe    := 'N';
        p_cod_error := 1;
        p_msj_error := 'Error al buscar el movimiento a reversar';

    end;
    savepoint reversion;
    --se llama al procedimiento para reversar las operaciones en el caso que exista el movimiento
    if v_existe = 'S' then
      begin
        --v_hora_rev := fug_obt_mov_hora;
       /*se agrega rotacion de usuarios para no generar error de pk en ge_movimientos*/
        v_rev_usuario := fu_obt_mov_usuario('APIPRONET');
        v_rev_hora := fu_obt_hora(v_rev_usuario);
        it.prg_rev_operacion(p_fecha             => v_fecha,
                             p_hora              => v_hora,
                             p_cod_usuario       => v_usuario,
                             p_cod_mod_padre     => v_cod_mod_padre,
                             p_cod_mad_padre     => V_cod_mad_padre,
                             p_cod_tra_padre     => v_cod_tra_padre,
                             p_cod_usu_reversion => v_rev_usuario,--substr(user, 1, 10),
                             p_hor_reversion     => v_rev_hora,--v_hora_rev,
                             p_es_nocturno       => 'N',
                             p_concepto          => 'REVERSION PRONET',
                             p_nro_ncredito      => null);
        p_cod_error := 0;
        p_msj_error := 'Se ha generado los movimientos de Reversa';
      exception
        when others then
          p_cod_error := 2;
          p_msj_error := 'Error en el proceso de Reversa -' || sqlerrm;
         rollback;
      end;
     
    end if;

    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Referencia : ' || p_mov_id || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_REV_OPERACION',
                            v_det_error,
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 3;
      p_msj_error := sqlerrm;
      v_det_error := 'Referencia : ' || p_mov_id || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAA_DEX.PR_GEN_REV_OPERACION',
                            v_det_error,
                            null,
                            null);
  end pr_gen_rev_operacion;
  function fu_es_conjunta(p_nro_cuenta in varchar2) return varchar2 is
    v_can_conjunta number;
  begin

    select count('S')
      into v_can_conjunta
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'Y'
       and rownum = 1;

    if nvl(v_can_conjunta, 0) > 0 then
      return 'S';
    else
      return 'N';
    end if;
  end;
  /* procedimiento para actualizar estado pin aleatorio*/
  procedure pr_act_estado_pin(p_cod_persona in varchar2,
                              p_pin         in number,
                              p_est_actual  out varchar2,
                              p_error       out number,
                              p_respuesta   out varchar2) is
    /*Variables*/
    v_cantidad number := 0;
    cantidad   number;
    cursor val_pin is
      select cod_persona, nro_pin, est_pin, intentos
        from ge_pin_aleatorio
       where cod_persona = p_cod_persona;
  begin
    for reg in val_pin loop
      cantidad   := reg.intentos;
      v_cantidad := cantidad + 1;
      /*numero de pin corresponde*/
      if reg.cod_persona = p_cod_persona and reg.nro_pin = p_pin and
         reg.est_pin = 'P' and cantidad in (0, 1, 2, 3) then
        update ge_pin_aleatorio
           set est_pin = 'A'
         where est_pin = 'P'
           and cod_persona = p_cod_persona
           and nro_pin = p_pin;
        commit;
        p_est_actual := 'A';
  /*numero de pin no corresponde */
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin != p_pin and
            reg.est_pin = 'P' and v_cantidad in (0, 1, 2, 3) then
        update ge_pin_aleatorio
           set intentos = v_cantidad
         where est_pin = 'P'
           and cod_persona = p_cod_persona;
        commit;
        p_est_actual := 'P';
        /*supero la cantidad de intentos permitidos*/
      elsif reg.cod_persona = p_cod_persona and reg.nro_pin != p_pin and
            reg.est_pin = 'P' and v_cantidad > 3 then
        update ge_pin_aleatorio
           set est_pin = 'I',
               intentos = v_cantidad
         where est_pin = 'P'
           and cod_persona = p_cod_persona;
        commit;
        p_est_actual := 'I';
      end if;
    end loop;
        p_error      := 0;
        p_respuesta  := 'PIN actualizado con exito';
  exception
    when others then
      p_error     := 1;
      p_respuesta := 'NOK- ' || sqlerrm;
  end pr_act_estado_pin;
 /*funcion que retorna usuario para evitar error de pk en ge_movimientos*/  
  function fu_obt_mov_usuario(p_tip_usuario in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_secuencia number;
    v_can_usuario   number;
    v_nro_usuario   number;
    v_usuario       ba_usuarios.cod_usuario%type;
  
  begin
    select count(*)
      into v_can_usuario
      from ba_cod_referencias
     where dominio = 'USU_TRA_PRONET'
       and abreviatura = p_tip_usuario;
  
    v_nro_secuencia := fue_obt_sig_secuencia('S_HOR_MOV_APIPRONET');
    v_nro_usuario   := mod(v_nro_secuencia, v_can_usuario);
    v_usuario       := it.FUE_OBT_VAL_USER_DOMINIO('USU_TRA_PRONET',
                                                   v_nro_usuario,
                                                   p_tip_usuario);
    return v_usuario;
  end;
   /*funcion que retorna hora para evitar error de pk en ge_movimientos*/  
  function fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora          ge_movimientos.hora%type;
    v_nro_secuencia number;
    v_nro_hora      number;
    v_ind_usuario   number;
  
  begin
    if upper(substr(p_cod_usuario, -1)) = 'T' then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, -1);
    end if;
  
    if v_ind_usuario > 0 then
      v_nro_secuencia := fue_obt_sig_secuencia('S_HOR_MOV_APIPRONET' ||
                                               v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_secuencia := fue_obt_sig_secuencia('S_HOR_MOV_APIPRONET');
    end if;
  
    v_nro_hora := mod(v_nro_secuencia, 86400);
  
    v_hora := TO_CHAR(trunc(v_nro_hora / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hora, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hora, 60), 'FM00');
  
    return v_hora;
  end;
  procedure pr_val_sal_mov_cliente_wp(p_nro_cuenta    in varchar2,
                                   p_monto         in number, --monto operacion
                                   p_moneda        in varchar2, ----Solo GS
                                   p_tip_operacion in varchar2, -- D=Deposito / E=Extraccion
                                   p_mto_total_gs  out number, --Total GS(monto operacion+monto movimiento)
                                   p_mto_limite    out number, --Mto limite establecido en parametro gral
                                   p_error         out number,
                                   p_respuesta     out varchar2) is

    v_mto_limite        ge_movimientos.monto%type:=null;
    v_cod_moneda        ba_monedas.cod_moneda%type;
    v_mon_cta           ba_monedas.cod_moneda%type;
    v_mto_tot_gs_diario ge_movimientos.monto%type := 0;
    v_cod_tra_padre     ge_transacciones.cod_transaccion%type;
    v_cod_transaccion   ge_transacciones.cod_transaccion%type;
    v_nom_par_gral      ge_parametros.parametro%type;
    v_nom_par_cant      ge_parametros.parametro%type;
    v_can_ope           number(3):=0;
    v_par_can_ope       ge_par_dinamicos.val_parametro%type;
    cursor c_movimientos is
      select m.monto, m.cod_moneda
        from ge_movimientos m
       where m.cod_tra_padre = v_cod_tra_padre
         and m.cod_transaccion = v_cod_transaccion
         and m.nro_cuenta = p_nro_cuenta
         and m.reversado = 'N';
  begin
    /*Proceso para el control de exceso de movimientos por cuenta*/
    /*Validaciones*/
    p_error := 0;
    p_respuesta := 'OK';
    if nvl(p_monto, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Debe ingresar el monto de la operacion: ';
      return;
    end if;
    if nvl(p_moneda, 'x') = 'x' then
      p_error     := 2;
      p_respuesta := 'Debe ingresar la moneda';
      return;
    end if;
    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'El numero de cuenta no puede ser nulo';
      return;
    end if;
    if nvl(p_tip_operacion, 'x') = 'x' then
      p_error     := 5;
      p_respuesta := 'Tipo de operacion no puede ser nulo';
      return;
    end if;
    v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    v_mon_cta := pag_cta.G_CTAS.cod_moneda;
    if v_mon_cta != p_moneda then
      p_error     := 6;
      p_respuesta := 'La moneda de la operacion no corresponde a la moneda de la cuenta';
      return;
    end if;
    /*Extracciones*/
    if p_tip_operacion = 'E' then
      v_nom_par_gral    := 'LIM_MTO_DIA_EXT_GRAL_PRO_WP';
      v_nom_par_cant    := 'PAR_CAN_OPE_EXT_PRO_WP';
      v_cod_transaccion := 8514;--8505--9730;
      v_cod_tra_padre   := 8536;--8906;
      /*Depositos*/
    elsif p_tip_operacion = 'D' then
      v_nom_par_gral    := 'LIM_MTO_DIA_DEP_GRAL_PRO_WP';
      v_nom_par_cant    := 'PAR_CAN_OPE_DEP_PRO_WP';
      v_cod_transaccion := 8515;--8513--9729;
      v_cod_tra_padre   := 8535;--8906;
    else
      p_error     := 7;
      p_respuesta := 'Tipo operacion incorrecto - ' || p_tip_operacion;
      return;
    end if;

    if v_mto_limite is null then
      /*busca el monto limite general por tipo de operacion */
      v_mto_limite := to_number(fug_obt_pardinamico(v_nom_par_gral,
                                                    null,
                                                    null,
                                                    v_cod_moneda));
    end if;
    /*Busca la cantidad limite por tipo de operacion*/
    if v_par_can_ope is null then
       v_par_can_ope := fug_obt_pardinamico(v_nom_par_cant);
    end if;
    for reg in c_movimientos loop
      if reg.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
           v_can_ope := v_can_ope + 1;
           v_mto_tot_gs_diario := v_mto_tot_gs_diario + reg.monto;
      end if;
    end loop;
    if v_mto_limite is not null or v_par_can_ope is not null then
      if nvl(v_mto_tot_gs_diario, 0) + p_monto > nvl(v_mto_limite,0) then
        p_error     := 10;
        p_respuesta := 'NOK-Monto supera el limite diario';
      elsif v_can_ope + 1 > nvl(v_par_can_ope,0) then
        p_error     := 10;
        p_respuesta := 'NOK-Cantidad supera el limite diario';
      else
        p_error     := 0;
        p_respuesta := 'OK';
      end if;
    end if;
    p_mto_total_gs := nvl(v_mto_tot_gs_diario, 0) + p_monto;
    p_mto_limite   := nvl(v_mto_limite, 0);
  exception
    when others then
      p_error     := 12;
      p_respuesta := 'NOK - ' || SQLERRM;
  end pr_val_sal_mov_cliente_wp;
end paa_dex;
/
