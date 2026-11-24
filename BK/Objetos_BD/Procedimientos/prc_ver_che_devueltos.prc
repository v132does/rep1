CREATE OR REPLACE PROCEDURE IT.prc_ver_che_devueltos(p_cod_oficina in number,
                                                  p_reg_pro     in out number,
                                                  p_reg_err     in out number,
                                                  p_reg_tot     in out number,
                                                  p_sum_monto   in out number,
                                                  p_procesar    in out varchar2,
                                                  p_tip_importe in out number,
                                                  p_cod_moneda  in varchar2) is
 


/*
------------------------------------------------------------------------
AVISO IMPORTANTE: IT CONSULTORES S.A. es titular de todos los derechos
del Software IT GESTION FINANCIERA, incluyendo los derechos del autor
sobre dicho software y por tanto, propietario del citado software y de
cualquier modificación y/o copia del mismo. Por este motivo, este programa
del Software IT GESTIÓN FINANCIERA debe ser mantenido bajo una adecuada
seguridad, y asegurar con ello que no haya acceso a copias o utilización no
autorizada por IT CONSULTORES S.A. COPYRIGHT IT CONSULTORES S.A. 2017.
Todos los derechos reservados.  
-------------------------------------------------------------------------
*/


 ok      boolean;
  v_est   varchar2(1);
  v_error varchar2(1000);
  -- Datos de la Cuenta
  v_cod_modalidad   ge_cuentas.cod_modalidad%type;
  v_cod_oficina     ge_cuentas.cod_oficina%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_estado          ge_cuentas.estado%type;
  v_cod_moneda      ge_cuentas.cod_moneda%type;
  v_saldo           ge_cuentas.sal_contable%type;
  v_nro_che_inicial cc_chequeras.nro_che_inicial%type;
  v_cant_repe       number(9);
  -- Datos Globales
  --   p_procesar varchar2(1) := 'S';
  g_modali      number(3) := 41;
  g_cuenta      varchar2(15) := '0';
  g_ok          varchar2(1) := 'N';
  g_error       varchar2(10000) := null;
  g_tiperr      varchar2(3);
  g_oficta      number(3) := to_number('0');
  g_est_che     varchar2(1);
  g_cuenta_cert ge_cuentas.nro_cuenta%type;
  v_contar       number(3) := 0;
  v_fecha       cc_che_devueltos.fecha%type;
  v_pos           number := 0;
  v_cod_submotivo cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo1       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo2       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo3       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo4       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo5       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo6       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo7       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo8       cc_che_rechazados_tmp.cod_submotivo%type;
  v_cod_submotivo9       cc_che_rechazados_tmp.cod_submotivo%type;
  v_exi_chq              varchar2(1) := 'N';
  v_fec_actual           date:= pag_cal.FU_OBT_FEC_ACTUAL(4);
  -- Cursor principal de cheques a Verificar
cursor clrec_cur is
 select c.nro_cuenta, c.nro_cheque, c.fecha, c.hora, c.usu_insercion, c.monto, c.cod_ofi_camara, c.cod_cau_principal,
      c.tipo, c.multa, c.sal_multa, c.cod_bco_receptor, c.nro_caja, c.regularizado, c.dev_com_directa, c.nro_linea,
      c.cod_cau_secundaria,p_tip_importe tip_importe, c.rowid registro, c.cod_moneda
     from cc_che_devueltos_tmp c
     where c.usu_insercion = user
       and c.cod_moneda = p_cod_moneda
     order by nro_linea, c.nro_cuenta;  --
  clrec clrec_cur%rowtype;

  procedure lp_act_cau_dev is
      v_cod_cau_dev          ge_par_causales.cod_causa%type;
      v_cod_cau_secundaria2  ge_par_causales.cod_causa%type;
      v_cod_cau_secundaria3  ge_par_causales.cod_causa%type;
      v_cod_cau_secundaria4  ge_par_causales.cod_causa%type;
      v_cod_cau_secundaria5  ge_par_causales.cod_causa%type;
      v_cod_cau_secundaria6  ge_par_causales.cod_causa%type;

      -- Cursor Principal
      cursor clrch_cur is
         select c.*, c.rowid registro
           from cc_che_devueltos_tmp c
          where usu_insercion = user;
      clrch clrch_cur%rowtype;

    begin

      if clrch_cur%isopen then
         close clrch_cur;
      end if;
      open clrch_cur;

      <<proceso>>
      loop

        fetch clrch_cur into clrch;
        exit when clrch_cur%notfound;
           begin
            select nvl (max(to_char(z.cod_causa)),-99)
              into v_cod_cau_dev
              from ge_par_causales z
             where z.parametro = 'COD_DEV_BCP'
               and to_number(z.val_parametro) =  to_number(clrch.cod_cau_principal)
               and rownum=1;
             if v_cod_cau_dev = -99 then
               raise_application_error(-20099,
                           'Error: Debe parametrizar código de causa inexistente'||''|| to_number(clrch.cod_cau_principal));
             end if ;
           exception
             when others then
               v_cod_cau_dev := null;
           end;

           begin
            select max(to_char(z.cod_causa))
             into v_cod_cau_secundaria2
             from ge_par_causales z
             where z.parametro = 'COD_DEV_BCP'
               and to_number(z.val_parametro) = to_number(trim(substr((clrch.cod_cau_secundaria), 1, 2)))
               and rownum=1; --- causas secundarias ---
           exception
             when others then
               v_cod_cau_secundaria2 := null;
           end;

           begin
            select max(to_char(z.cod_causa))
             into v_cod_cau_secundaria3
             from ge_par_causales z
             where z.parametro = 'COD_DEV_BCP'
               and to_number(z.val_parametro)  = to_number(trim(substr((clrch.cod_cau_secundaria), 3, 2)))
               and rownum=1;
           exception
              when others then
               v_cod_cau_secundaria3 := null;
           end;

           begin
            select max(to_char(z.cod_causa))
             into v_cod_cau_secundaria4
             from ge_par_causales z
             where z.parametro = 'COD_DEV_BCP'
               and to_number(z.val_parametro) = to_number(trim(substr((clrch.cod_cau_secundaria), 5, 2)))
               and rownum=1;
           exception
              when others then
               v_cod_cau_secundaria4 := null;
           end;

           begin
             select max(to_char(z.cod_causa))
              into v_cod_cau_secundaria5
             from ge_par_causales z
             where z.parametro = 'COD_DEV_BCP'
               and to_number(z.val_parametro) = to_number(trim(substr((clrch.cod_cau_secundaria) , 7, 2)))
               and rownum=1;
           exception
              when others then
               v_cod_cau_secundaria5 := null;
           end;

           begin
             select max(to_char(z.cod_causa))
              into v_cod_cau_secundaria6
              from ge_par_causales z
              where z.parametro = 'COD_DEV_BCP'
                and to_number(z.val_parametro) = to_number(trim(substr((clrch.cod_cau_secundaria) , 9, 2)))
                and rownum=1;
           exception
              when others then
               v_cod_cau_secundaria6 := null;
           end;
         --
          
          update cc_che_devueltos_tmp x
             set x.cod_cau_principal  = nvl(v_cod_cau_dev,cod_cau_principal),
                 x.fecha=to_char(v_fec_actual,'dd/mm/yyyy') 
            where x.rowid = clrch.registro;

          If v_cod_cau_secundaria2 is not null then ---2
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  = v_cod_cau_secundaria2
              where x.rowid = clrch.registro;
          End if;

          If v_cod_cau_secundaria3 is not null and v_cod_cau_secundaria2 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria2||','||v_cod_cau_secundaria3 ---null
              where x.rowid = clrch.registro;
          elsif v_cod_cau_secundaria3 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria3 ---null
              where x.rowid = clrch.registro;
          End if;

          If v_cod_cau_secundaria3 is not null and v_cod_cau_secundaria2 is not null and v_cod_cau_secundaria4 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria2||','||v_cod_cau_secundaria3||','||v_cod_cau_secundaria4 ---null
              where x.rowid = clrch.registro;
          elsif v_cod_cau_secundaria4 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria4 ---null
              where x.rowid = clrch.registro;
          End if;

          If v_cod_cau_secundaria3 is not null and v_cod_cau_secundaria2 is not null and v_cod_cau_secundaria4 is not null
              and v_cod_cau_secundaria5 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria2||','||v_cod_cau_secundaria3||','||v_cod_cau_secundaria4||','||v_cod_cau_secundaria5 ---null
              where x.rowid = clrch.registro;
          elsif v_cod_cau_secundaria5 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria5 ---null
              where x.rowid = clrch.registro;
          End if;

          If v_cod_cau_secundaria3 is not null and v_cod_cau_secundaria2 is not null and v_cod_cau_secundaria4 is not null
              and v_cod_cau_secundaria5 is not null and v_cod_cau_secundaria6 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria2||','||v_cod_cau_secundaria3||','||v_cod_cau_secundaria4||','||v_cod_cau_secundaria5||','||v_cod_cau_secundaria6 ---null
              where x.rowid = clrch.registro;
          elsif v_cod_cau_secundaria6 is not null then
            update cc_che_devueltos_tmp x
               set x.cod_cau_secundaria  =  v_cod_cau_secundaria6 ---null
              where x.rowid = clrch.registro;
          End if;
          if clrch.cod_sub_motivo is not null then
             v_cod_submotivo := '';
            v_cod_submotivo1 := it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,1, 1),v_cod_cau_dev);
             v_cod_submotivo2 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,2, 1),v_cod_cau_dev);
             v_cod_submotivo3 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,3, 1),v_cod_cau_dev);
             v_cod_submotivo4 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,4, 1),v_cod_cau_dev);
             v_cod_submotivo5 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,5, 1),v_cod_cau_dev);
             v_cod_submotivo6 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,6, 1),v_cod_cau_dev);
             v_cod_submotivo7 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,7, 1),v_cod_cau_dev);
             v_cod_submotivo8 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,8, 1),v_cod_cau_dev);
             v_cod_submotivo9 :=it.fug_obt_cau_submotivo (substr(clrch.cod_sub_motivo,9, 1),v_cod_cau_dev);
            if v_cod_submotivo1 is not null then
               v_cod_submotivo := v_cod_submotivo1;
            end if;
            if v_cod_submotivo2 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo2;
            end if;
            if v_cod_submotivo3 is not null then 
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo3;
            end if;
            if v_cod_submotivo4 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo4;
            end if;
            if v_cod_submotivo5 is not null then 
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo5;
            end if;
            if v_cod_submotivo6 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo6;
            end if;
            if v_cod_submotivo7 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo7;
            end if; 
            if v_cod_submotivo8 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo8;
            end if;
            if v_cod_submotivo9 is not null then
               v_cod_submotivo := v_cod_submotivo||','||v_cod_submotivo9;
            end if;
             
             update cc_che_devueltos_tmp x
               set x.cod_sub_motivo = v_cod_submotivo
             where x.rowid = clrch.registro;
          end if;           
      end loop;

      close clrch_cur;

    end;
  --- Procedimiento para validar.
  procedure lp_validar_detalle(p_nrcuent  in varchar2,
                               p_nrcheque in number,
                               p_importe  in out number,
                               p_banco    in number,
                               p_ok       out boolean) is

    PROCEDURE pp_validar_cuenta(p_nrcuent in varchar2, p_ok out boolean) is
      v_tip_dev varchar2(1);
    begin
      p_ok := true;
      if g_cuenta <> nvl(p_nrcuent, 'a') then
        -- solo si hubo cambio de cta
        pag_cta.PR_OBT_CUENTA(p_nrcuent);
        --cuentas corrientes
        v_nro_cuenta    := p_nrcuent;
        v_estado        := pag_cta.g_ctas.estado;
        v_cod_oficina   := pag_cta.g_ctas.cod_oficina;
        v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
        v_cod_moneda    := pag_cta.g_ctas.cod_moneda;
        v_saldo         := pag_cta.g_ctas.sal_disponible;

        if pag_cta.g_cod_error = '12' then
          --Cuenta Inexistente
          v_nro_cuenta    := null;
          v_estado        := null;
          v_cod_oficina   := null;
          v_cod_modalidad := null;
          v_cod_moneda    := null;
          v_saldo         := null;
          p_ok            := false; --No debe permitir procesar en estos casos, Agregado en Fecha 25/02/2010
        end if;
      end if;

      if v_estado in ('C', 'T', 'D', 'P') or v_estado is null then
        --p_ok := false;
        if v_estado = 'C' then
          g_error   := 'Cuenta Cancelada';
          v_tip_dev := 'C';
        elsif v_estado in ('T', 'D') then
          g_error   := 'Cuenta Bloqueada';
          v_tip_dev := 'B';
        elsif v_estado = 'P' then
          g_error   := 'Cuenta Cerrada';
          v_tip_dev := 'C';
        elsif v_estado is null then
          g_error   := 'Cuenta no existe o con estado incorrecto';
          v_tip_dev := null;
        end if;
        If v_tip_dev is not null then
          begin
            g_tiperr := fug_obt_cau_devolucion('D', v_tip_dev);
          exception
            when no_data_found then
              null;
          end;
        End if;
      end if;
    exception
      when no_data_found then
        g_error         := 'Cuenta no existe';
        v_cod_modalidad := null;
        p_ok            := false;
      when others then
        if g_error is null then
          g_error := 'Al buscar cuenta.';
        end if;
        p_ok := false;
    end pp_validar_cuenta;

    PROCEDURE pp_verifica_estado_cheque(p_nro_cuenta  in varchar2,
                                        p_cod_oficina in number,
                                        p_nro_cheque  in number,
                                        p_importe     in out number,
                                        p_ok          in out boolean) IS
      v_error       varchar2(2000);
      v_cuenta      varchar2(15);
      v_estado      varchar2(1);
      v_desc_estado varchar2(100);
    BEGIN
      g_est_che := null;
      g_est_che := PAC_CHE.FU_OBT_EST_CHE(p_nro_cuenta,
                                          p_nro_cheque,
                                          
                                          v_error);
      --Verifica si existe el cheque de lo contrario da un mensaj.
      If v_error is not null then
        If g_ERROR is not null then
          g_ERROR := g_ERROR || ' - ' || v_error;
        else
          g_ERROR := v_error;
        End if;
        p_ok := false;
      end if;
      ---
        v_estado := pac_che.FU_CON_CAM_EST_CHE(p_nro_cuenta,
                                               p_nro_cheque,
                                               null,
                                               p_importe,
                                            
                                               v_nro_che_inicial,
                                               v_error,
                                               v_cuenta);


        if v_estado not in ('C','G','P','O') then
           If v_error is not null and rtrim(v_error) <> 'G' then
              g_ERROR := g_ERROR || ' - ' || 'Cheque en estado ' || g_est_che || '(' ||
                   v_desc_estado || ')';
              p_ok    := false;
           end if;
        end if;
        If instr(v_error,'Inexistente') <> 0 then
           If v_error is not null and rtrim(v_error) <> 'G' then
          g_ERROR := g_ERROR || ' - ' || 'Cheque en estado ' || g_est_che || '(' ||
                   v_desc_estado || ')';
          p_ok    := false;
          end if;
        End if;
         ---
        If g_est_che = 'O' then
           begin
              g_tiperr := fug_obt_cau_devolucion('D', 'O');
           exception
             when no_data_found then
               null;
           end;

           begin
            select g_error || '-' || descripcion
              into g_error
              from ge_causales
             where ge_causales.cod_causa =
                   (select cod_causa
                      from cc_che_ord_no_pagos
                     where nro_cheque = p_nro_cheque);
           exception
             when others then
               null;
           end;
        End if;

    exception
      when others then
        raise_application_error(-20004,
                                'Error en pp_ver_est_che ' ||
                                replace(sqlerrm, 'ORA-', ''));
    END;

    procedure pp_ver_bco_receptor(p_banco in number, p_ok in out boolean) is
      v_existe varchar2(1);
    begin

      begin
        select 'S'
          into v_existe
          from ge_bancos b
         where b.cod_banco = p_banco
           and b.estado = 'A'
           and b.ubicacion = 'L';
      exception
        when others then
          if g_error is null then
            g_error := 'Código de Banco no válido.'; 
          else
            g_error := g_error || '/Código de Banco no válido.';
          end if;
          p_ok := false;
      end;
    end pp_ver_bco_receptor;

    --Agregado para validar si la cuenta tiene firmantes inhibidos, 01/01/2010
    procedure pp_ver_fir_cuenta(p_nro_cuenta in varchar2,
                                p_ok         in out boolean) is
      v_inhibido varchar2(1) := 'N';
    begin

      select fuc_ver_fir_inhibidos(p_nro_cuenta) into v_inhibido from dual;

      if v_inhibido = 'S' then
        if g_error is null then
          g_error := 'Advertencia: Cuenta con firmante Inhabilitado - Ley de Cheques.';
        else
          g_error := g_error ||
                     '/Advertencia: Cuenta con firmante Inhabilitado - Ley de Cheques.';
        end if;
      end if;
    end pp_ver_fir_cuenta;

  begin
    p_ok := true;
    if nvl(p_nrcheque, 0) <= 0 then
      if g_error is null then
        g_error := 'Numero de cheque incorrecto.';
      end if;
      p_ok := false;
    end if;
    pp_validar_cuenta(p_nrcuent, p_ok);
    pp_ver_bco_receptor(p_banco, p_ok);
    pp_ver_fir_cuenta(p_nrcuent, p_ok); --Verifica Firmantes Inhabilitados, 01/02/2010
    if p_ok then
      g_ok := 'S';
    else
      g_ok := 'N';
    end if;
    g_cuenta := p_nrcuent;
    g_oficta := v_cod_oficina;
    g_modali := v_cod_modalidad;
    p_ok     := true;
    --Solo debe verificar el cheque si existe la cuenta
    If v_cod_modalidad is not null then
      pp_verifica_estado_cheque(v_nro_cuenta,
                                v_cod_oficina,
                                p_nrcheque,
                                p_importe,
                                p_ok);
    End if;
    if g_ok = 'N' then
      -- si la cuenta tuvo problemas
      p_ok := false;
    end if;
    if nvl(p_importe, 0) <= 0 then
      if g_error is null then
        g_error := 'Importe incorrecto.';
      else
        g_error := g_error || '/importe incorrecto';
      end if;
      p_ok := false;
    end if;
    --Verificacion que no este devuelto el cheque
    begin
      select 'S'
        into v_exi_chq
        from cc_che_devueltos
       where nro_cheque = p_nrcheque
         and monto = p_importe
         and cod_bco_receptor = p_banco
         and fecha= v_fec_actual;
      If v_exi_chq = 'S' then
        g_error := g_error || '/Cheque ya devuelto';
        p_ok := false;
      end if;
    exception    
      when no_data_found then
        v_exi_chq := 'N';
    end;
  end;

  --
begin
  p_reg_pro := 0;
  p_reg_err := 0;
  p_reg_tot := 0;

  -- Suma y total de cheques a procesar
  select count(*), sum(monto)
    into p_reg_tot, p_sum_monto
    from cc_che_devueltos_tmp c
   where c.usu_insercion = user
     and cod_moneda = p_cod_moneda;

  --Verificar si existen cheques duplicados
  Begin
    select count(*)
      into v_cant_repe
      from (select nro_cheque, nro_cuenta, usu_insercion
              from cc_che_devueltos_tmp
             where usu_insercion = user
               and cod_moneda = p_cod_moneda
             group by nro_cheque, nro_cuenta, usu_insercion
            having count(*) > 1);
  exception
    when no_data_found then
      v_cant_repe := 0;
  end;

  if v_cant_repe > 0 then
    --Mensaje de error para identificar el problema
    g_error := ' - Nro.de Cheque Duplicado - Linea: ';
    -- Si existe cheques repetidos ingresa en la tabla de errores
    insert into cc_che_dev_errores e
      (nro_cuenta, nro_cheque, msj_error, importe, cod_banco, tip_importe)
      select t.nro_cuenta,
             t.nro_cheque,
             g_error || to_char(t.nro_linea),
             t.monto,
             t.cod_bco_receptor,
             t.tip_importe
        from cc_che_devueltos_tmp t
       where t.usu_insercion = user
         and exists (select 0
                from cc_che_devueltos_tmp r
               where r.usu_insercion = user
                 and r.nro_cuenta = t.nro_cuenta
                 and r.nro_cheque = t.nro_cheque
                 and cod_moneda = p_cod_moneda
               group by nro_cheque, nro_cuenta, usu_insercion
              having count(*) > 1);

    -- No procesa si existen registros duplicados
    p_procesar := 'N';
    p_reg_err  := p_reg_err + nvl(v_cant_repe, 0);
  end if;

  if g_error is null then
    if clrec_cur%isopen then
      close clrec_cur;
    end if;
    open clrec_cur;
      update cc_che_devueltos_tmp
      set tip_importe = p_tip_importe
      where usu_insercion = user
        and tip_importe is null;
    /* ciclo de Verificacion principal */
    <<proceso>>
    loop
      fetch clrec_cur
        into clrec;
      exit when clrec_cur%notfound;
      g_error  := null;
      g_tiperr := null;

      lp_validar_detalle(clrec.nro_cuenta,
                         clrec.nro_cheque,
                         clrec.monto,
                         clrec.cod_bco_receptor,
                         ok);
      --Para ver si se va a ejecutar el procesamiento
      --If ok = false then
      IF ok = FALSE AND g_error NOT LIKE '%/Cheque ya devuelto%' -- agregado 12/07/25
        THEN
        p_procesar := 'N';
      END  IF;
       if g_error is not null then
          if nvl(g_est_che,'A') <> 'O' then
            -- if nvl(v_estado,'X') not in ('C','P') THEN
            if v_estado not in ('C','P') THEN
                  if g_error not like '%Cuenta Cancelada%' OR g_error not like '%Cuenta Cerrada%'  then
                     if g_error <> 'Advertencia: Cuenta con firmante Inhabilitado - Ley de Cheques.' then
                        g_error := g_error || '- Linea: ' || clrec.nro_linea;
                        insert into cc_che_dev_errores
                        (nro_cuenta, nro_cheque, msj_error, importe, cod_banco,tip_importe)
                        values
                        (clrec.nro_cuenta,
                        clrec.nro_cheque,
                        substr(g_error, 1, 100),
                        clrec.monto,
                        clrec.cod_bco_receptor,
                        clrec.tip_importe);
                        g_error   := null;
                        g_tiperr  := null;
                        v_est     := 'N';
                        p_reg_err := p_reg_err + 1;
                      end if;
                  end if;
              elsif v_estado in ('C','P') THEN
                if upper(g_error) like upper('%Cheque%Inexistente para la cuenta%') then
                      g_error := g_error || '- Linea: ' || clrec.nro_linea;
                        insert into cc_che_dev_errores
                        (nro_cuenta, nro_cheque, msj_error, importe, cod_banco,tip_importe)
                        values
                        (clrec.nro_cuenta,
                        clrec.nro_cheque,
                        substr(g_error, 1, 100),
                        clrec.monto,
                        clrec.cod_bco_receptor,
                        clrec.tip_importe);
                        g_error   := null;
                        g_tiperr  := null;
                        v_est     := 'N';
                        p_reg_err := p_reg_err + 1;
                ELSE
                    g_error := g_error || '- Linea: ' || clrec.nro_linea;
                        insert into cc_che_dev_errores
                        (nro_cuenta, nro_cheque, msj_error, importe, cod_banco,tip_importe)
                        values
                        (clrec.nro_cuenta,
                        clrec.nro_cheque,
                        substr(g_error, 1, 100),
                        clrec.monto,
                        clrec.cod_bco_receptor,
                        clrec.tip_importe);
                        g_error   := null;
                        g_tiperr  := null;
                        v_est     := 'N';
                        p_reg_err := p_reg_err + 1;     
                end if;
          elsif v_estado is null  THEN -- agregado 12/07/25
                     -- g_error :='Cuenta inexistente'
                      g_error := g_error || '- Linea: ' || clrec.nro_linea;
                        insert into cc_che_dev_errores
                        (nro_cuenta, nro_cheque, msj_error, importe, cod_banco,tip_importe)
                        values
                        (clrec.nro_cuenta,
                        clrec.nro_cheque,
                        substr(g_error, 1, 100),
                        clrec.monto,
                        clrec.cod_bco_receptor,
                        clrec.tip_importe);
                        g_error   := null;
                        g_tiperr  := null;
                        v_est     := 'N';
                        p_reg_err := p_reg_err + 1;
            end if;
          
          ELSE
            g_error := g_error || '- Linea: ' || clrec.nro_linea;
            insert into cc_che_dev_errores
            (nro_cuenta, nro_cheque, msj_error, importe, cod_banco,tip_importe)
            values
            (clrec.nro_cuenta,
            clrec.nro_cheque,
            substr(g_error, 1, 100),
            clrec.monto,
            clrec.cod_bco_receptor,
            clrec.tip_importe);
            g_error   := null;
            g_tiperr  := null;
            v_est     := 'N';
            p_reg_err := p_reg_err + 1;
          end if;
       end if;
    end loop proceso;

    if clrec_cur%rowcount = 0 then
      Raise_application_error(-20002,
                              'No existen registros a ser procesados.');
    else
      p_reg_tot := clrec_cur%rowcount;
    end if;
    close clrec_cur;
  End if;
  lp_act_cau_dev;
  commit;

exception
  when others then
    raise_application_error(-20099,
                            'Error: ' || replace(sqlerrm, 'ORA-', ''));
end prc_ver_che_devueltos;
/
