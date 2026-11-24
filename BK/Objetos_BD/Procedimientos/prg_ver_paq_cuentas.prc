CREATE OR REPLACE PROCEDURE IT.PRG_VER_PAQ_CUENTAS (p_cod_paquete in ge_paq_cuentas.cod_paquete%type,
                                                p_cod_persona in ba_personas.cod_persona%type,
                                                p_nro_secuencia in ge_paq_cuentas.nro_secuencia%type,
                                                p_nro_cuenta in ge_cuentas.nro_cuenta%type default null,
                                                p_error in out varchar2,
                                                p_accion in varchar2 default 'U') is

  g_error   varchar2(10000) := null;
--se agrega el parametro p_accion para diferenciar cuando es Cancelacion(C) -- DYDMR-12035 -- dic/2019

--Cargar Variable de Error
procedure lp_cargar_error(p_error in varchar2) is

begin
   if p_error is not null then
      if g_error is null then
         g_error := p_error;
      else
         g_error := g_error||';  '||p_error;
      end if;
   end if;
end;

--Validar Cantidades Minimas y Maximas por Módulo
procedure lp_val_cant_productos is
   v_cant_min_av   number;
   v_cant_max_av   number;
   v_cant_min_cc   number;
   v_cant_max_cc   number;
   v_cant_min_ta   number;
   v_cant_max_ta   number;
   v_cant_av       number;
   v_cant_cc       number;
   v_cant_ta       number;
   v_error         varchar2(100);
   r_paquete ge_paquetes%rowtype;
   v_subMod_av    number(3);
   v_subMod_cc    number(3);
begin

   --Traer datos del paquete
   select *
     into r_paquete
    from ge_paquetes p
    where p.cod_paquete = p_cod_paquete;

   select t.cod_sub_modalidad
     into v_subMod_av
     from ge_paq_modalidades t
    where cod_paquete = p_cod_paquete
      and cod_modalidad = 31;

   select t.cod_sub_modalidad
     into v_subMod_cc
     from ge_paq_modalidades t
    where cod_paquete = p_cod_paquete
      and cod_modalidad = 41;

   v_error     := null;

   --Traer Cantidades Parametrizadas
   v_cant_min_av  := fug_obt_pardinamico('PRO_MIN_PAQUETE',3,31,r_paquete.cod_moneda,null,v_subMod_av);
   v_cant_max_av  := fug_obt_pardinamico('PRO_MAX_PAQUETE',3,31,r_paquete.cod_moneda,null,v_subMod_av);
   v_cant_min_cc  := fug_obt_pardinamico('PRO_MIN_PAQUETE',4,41,r_paquete.cod_moneda,null,v_subMod_cc);
   v_cant_max_cc  := fug_obt_pardinamico('PRO_MAX_PAQUETE',4,41,r_paquete.cod_moneda,null,v_subMod_cc);
   v_cant_min_ta  := 0;
   v_cant_max_ta  := 1;

   --Validar Cantidades de CUENTAS DE AHORRO
   if v_cant_min_av is null then
      v_error := 'Falta Parametrizar Cantidad Mínima para el Módulo de Ahorros';
      lp_cargar_error(v_error);
   else
      select count(1)
        into v_cant_av
        from ge_paq_cuentas t
       where t.cod_paquete = p_cod_paquete
         and t.cod_persona = p_cod_persona
         and t.nro_secuencia = p_nro_secuencia
         and t.cod_modulo = 3
         and t.cod_modalidad = 31;
      if v_cant_av not between  v_cant_min_av and nvl(v_cant_max_av,9) then
         v_error := 'Cantidad de Cuentas de Ahorros Incorrecta';
         lp_cargar_error(v_error);
      end if;
   end if;

   --Validar Cantidades de CUENTAS CORRIENTES
   if v_cant_min_cc is null then
      v_error := 'Falta Parametrizar Cantidad Mínima para el Módulo de Cuentas Corrientes';
      lp_cargar_error(v_error);
   else
      select count(1)
        into v_cant_cc
        from ge_paq_cuentas t
       where t.cod_paquete = p_cod_paquete
         and t.cod_persona = p_cod_persona
         and t.nro_secuencia = p_nro_secuencia
         and t.cod_modulo = 4
         and t.cod_modalidad = 41;
      if v_cant_cc not between  v_cant_min_cc and nvl(v_cant_max_cc,9) then
         v_error := 'Cantidad de Cuentas Corrientes Incorrecta';
         lp_cargar_error(v_error);
      end if;
   end if;

   --Validar Cantidades de TARJETAS DE CREDITO
   if v_cant_min_ta is null then
      v_error := 'Falta Parametrizar Cantidad Mínima para el Módulo de Tarjetas';
      lp_cargar_error(v_error);
   else
      select count(1)
        into v_cant_ta
        from ge_paq_cuentas t
       where t.cod_paquete = p_cod_paquete
         and t.cod_persona = p_cod_persona
         and t.nro_secuencia = p_nro_secuencia
         and t.cod_modulo = 5;
      if v_cant_ta not between  v_cant_min_ta and nvl(v_cant_max_ta,1) then
         v_error := 'Cantidad de Tarjetas Incorrecta';
         lp_cargar_error(v_error);
      end if;
   end if;

end lp_val_cant_productos;

--Cantidad de Productos por paquete
procedure lp_can_pro_paquetes is
   v_cli_especial VARCHAR2(1) := 'N';
   v_cod_seg_preferente ge_clientes.cod_seg_preferente%type;
   ---
   cursor c_paq_modalidades is
   /*select a.cod_modulo, a.cod_modalidad, a.afinidad, a.sub_afinidad, a.cod_sub_modalidad
   from   ge_paq_modalidades a
   where  a.cod_paquete = p_cod_paquete;*/ -- Fase I
   select distinct nvl(p.cod_moneda,d.cod_moneda) cod_moneda,
          m.cod_modulo, m.cod_modalidad, m.afinidad, m.sub_afinidad,
          nvl(m.cod_sub_modalidad, d.cod_sub_modalidad) cod_sub_modalidad,
          d.VAL_PARAMETRO can_pro_paquetes
   from   ge_paq_modalidades m, ge_paquetes p, ge_par_dinamicos d
   where  m.cod_paquete = p.cod_paquete
     and  p.cod_paquete = p_cod_paquete
     and  m.cod_modulo = d.cod_modulo
     and  m.cod_modalidad = d.cod_modalidad
     and  nvl(m.cod_sub_modalidad, m.sub_afinidad) = d.cod_sub_modalidad --tarjetas se crea sub_modalidad = sub_afinidad
     and  nvl(p.cod_moneda,d.cod_moneda) = nvl(d.cod_moneda,p.cod_moneda)
     and  d.parametro = 'CAN_PRO_PAQUETE'
     order by m.COD_MODULO, m.COD_MODALIDAD, d.VAL_PARAMETRO desc; -- Fase II
   ---
   v_can_cta number;
   r_paquete ge_paquetes%rowtype;
   v_error         varchar2(100);

begin
   begin
     -- Verifico si el cliente es vip
     Select 'S', a.cod_seg_preferente
       into v_cli_especial, v_cod_seg_preferente
       from ge_clientes a
      where a.cod_persona = p_cod_persona
        and a.cli_especial = 'S';
   exception
     when no_data_found then
        v_cli_especial := 'N';
        v_cod_seg_preferente := null;
     when others then
        v_error := 'Error Obt.Cli.Especial:'||sqlerrm;
        lp_cargar_error(v_error);
   end;
   if v_error is null then
      --Adherir únicamente a los paquetes asociados al Segmento Preferente del Cliente Preferente
      if v_cli_especial = 'S' then
         if v_cod_seg_preferente is null then
            v_error := 'Segmento Preferente del Cliente no se encuentra definido.';
            lp_cargar_error(v_error);
         end if;
         if v_error is null then
            begin
               select *
                 into r_paquete
                 from ge_paquetes p
                where p.cod_paquete = p_cod_paquete
                  and p.cod_seg_preferente = v_cod_seg_preferente;
            exception
              when no_data_found then
                 v_error := 'Paquete no habilitado para tipo de Cliente Preferente.';
                 lp_cargar_error(v_error);
              when others then
                 v_error := 'Error Obt.Paquete:'||sqlerrm;
                 lp_cargar_error(v_error);
            end;
         end if;
      else
         begin
            select *
              into r_paquete
              from ge_paquetes p
             where p.cod_paquete = p_cod_paquete;
         exception
            when no_data_found then
               v_error := 'Paquete no existe.';
                lp_cargar_error(v_error);
            when others then
               v_error := 'Error Obt.Paquete:'||sqlerrm;
               lp_cargar_error(v_error);
         end;
      end if;

      if v_error is null then
         for i in c_paq_modalidades loop
            v_can_cta := 0;

            if i.cod_modulo = 5 then
               select nvl(count(*),0)
               into   v_can_cta
               from   ge_paq_cuentas a, ge_cuentas g
               where  a.nro_cuenta = g.nro_cuenta
               and    a.cod_paquete = p_cod_paquete
               and    a.cod_persona = p_cod_persona
               and    a.cod_modulo = 5
               and    a.cod_modulo = i.cod_modulo
               and    a.cod_modalidad = i.cod_modalidad
               and    a.sub_afinidad = i.cod_sub_modalidad -- tarjetas se crea sub_modalidad = sub_afinidad
               and    a.afinidad = i.afinidad
               and    a.sub_afinidad = i.sub_afinidad
               and    g.cod_moneda = i.cod_moneda;
            else
               select nvl(count(*),0)
               into   v_can_cta
               from   ge_paq_cuentas a, ge_cuentas g
               where  a.nro_cuenta = g.nro_cuenta
               and    a.cod_paquete = p_cod_paquete
               and    a.cod_persona = p_cod_persona
               and    a.cod_modulo in (3,4)
               and    a.cod_modulo = i.cod_modulo
               and    a.cod_modalidad = i.cod_modalidad
               and    a.cod_sub_modalidad = i.cod_sub_modalidad
               and    g.cod_moneda = i.cod_moneda;
            end if;

           if i.can_pro_paquetes <> 0 then
              if nvl(v_can_cta,0) = 0 then
                   v_error := 'Falta definir Cuenta/s para modalidad '
                  || FUG_OBT_DES_MODAL(i.cod_modulo,i.cod_modalidad)
                  || ' Moneda '
                  || i.cod_moneda;
                  lp_cargar_error(v_error);
              elsif nvl(v_can_cta,0) <> i.can_pro_paquetes then
                    v_error := 'Cantidad de Cuentas no coincide con definidas para modalidad '
                    || FUG_OBT_DES_MODAL(i.cod_modulo,i.cod_modalidad)
                    || ' Moneda '||i.cod_moneda;
                    lp_cargar_error(v_error);
               end if;
            end if;

            if v_error is null then
               v_can_cta := 0;
            else
               EXIT WHEN v_error is not null;
            end if;

         end loop;
      end if;
   end if;
end;

--Validar los Intervinientes de las cuentas (Regimen de Firmas)
procedure lp_val_intervinientes is
   v_error varchar2(100);
   v_firma varchar2(100);
   v_firma_ant varchar2(100);
   v_cont number:= 0;
begin

    for j in (select z.nro_cuenta
                from ge_paq_cuentas z
               where z.cod_persona = p_cod_persona
                 and z.cod_paquete = p_cod_paquete) loop

          v_cont  := v_cont + 1;
          v_firma := null;

          for k in ( select x.cod_persona || x.relacion relac
                       from ge_cta_clientes x
                      where x.cod_modulo in (3, 4) --Ahorro y CtaCte
                        and x.nro_cuenta = j.nro_cuenta
                        order by x.cod_persona) loop
              v_firma := v_firma ||k.relac;
          end loop;

          if v_cont > 1 then
            if v_firma_ant != v_firma then
               v_error := 'Las Cuentas Seleccionadas deben tener los mismos Intervinientes';
            end if;
          end if;

          v_firma_ant := v_firma;
     end loop;

     lp_cargar_error(v_error);

end lp_val_intervinientes;

--Validar Cuenta Corriente
procedure lp_val_cta_corriente is
  v_estado ge_cuentas.estado%type;
  v_error varchar2(100);
begin

  v_estado := pag_cta.g_ctas.estado;

  if v_estado in ('C','T','D','P'/*,'I'*/) or
      v_estado is null then
      if v_estado = 'C' then
         v_error := 'Cuenta Cancelada';
      elsif v_estado in ('T','D') then
         v_error := 'Cuenta Bloqueada';
      elsif v_estado = 'P' then
         v_error := 'Cuenta Cerrada';
      elsif v_estado = 'I' then
         v_error := 'Cuenta Inactiva';
      elsif v_estado is null then
         v_error := 'Cuenta no existe o con estado incorrecto';
      end if;
      lp_cargar_error(v_error);
   end if;

end lp_val_cta_corriente;

--Validar Cuenta de Ahorro
procedure lp_val_cta_ahorro is
  v_estado ge_cuentas.estado%type;
  v_error varchar2(100);
begin

  v_estado := pag_cta.g_ctas.estado;

  if v_estado in ('C','T','D','P'/*,'I'*/) or
      v_estado is null then
      if v_estado = 'C' then
         v_error := 'Cuenta Cancelada';
      elsif v_estado in ('T','D') then
         v_error := 'Cuenta Bloqueada';
      elsif v_estado = 'P' then
         v_error := 'Cuenta Cerrada';
      elsif v_estado = 'I' then
         v_error := 'Cuenta Inactiva';
      elsif v_estado is null then
         v_error := 'Cuenta no existe o con estado incorrecto';
      end if;
      lp_cargar_error(v_error);
   end if;

end lp_val_cta_ahorro;

--Validar Tarjeta
procedure lp_val_tarjeta is
   r_ctaTar  ta_cta_tarjetas%rowtype;
   v_error   varchar2(100);
   v_sub_afinidad ta_tipos.sub_afinidad%type;
   v_es_solicitado varchar2(1) := 'N';
begin

   select *
     into r_ctaTar
     from ta_cta_tarjetas t
    where t.nro_cuenta = pag_cta.g_ctas.nro_cuenta;

    --Validar el Estado
    if r_ctaTar.Estado = 'C' then
      /*
      || Si es el producto es una tarjeta de crédito,
      || se permite el estado cancelado si la solicitud es menor a 10 días.
      || Cuando se da de alta desde la procesadora, viene con estado inactivo,
      || por lo que desde ITGF se "ve" la tarjeta como Cancelada.
      || RABF - 03/06/2011
      */
       begin
          select 'S'
            into  v_es_solicitado
            from  ta_cta_tarjetas a, ta_solicitudes t,
                  ta_tarjetas b
           where  a.nro_cuenta = b.nro_cuenta
             and  a.fec_cancelacion is null
             and  a.estado = 'C'
             and  a.nro_solicitud = t.nro_solicitud
             and  t.cod_estado = 'TIA'
             and  b.vigente = 'S'
             and  b.cod_estado = 1
             and  b.fec_emision >= (pag_cal.FU_OBT_FEC_ACTUAL(5) - nvl(fug_obt_pardinamico('CAN_DIA_TAR_PREF',null,null,null,null,7),0))
             and  b.cod_persona = p_cod_persona
             and  a.nro_cuenta = pag_cta.g_ctas.nro_cuenta
             and  not t.cod_canal is null; -- JIRA 1614--
       exception
          when no_data_found then
             v_error := 'Cuenta Cancelada';
             lp_cargar_error(v_error);
       end;
    end if;

    begin
      select distinct sub_afinidad
        into v_sub_afinidad
        from ge_paq_modalidades
       where cod_paquete = p_cod_paquete
         and cod_modulo = r_ctaTar.Cod_Modulo
         and cod_modalidad  = r_ctaTar.cod_modalidad
         and afinidad = r_ctaTar.Afinidad;
         --and sub_afinidad = r_ctaTar.Sub_Afinidad;
    exception
      when no_data_found then
         v_error := 'La tarjeta no Tiene Sub Afinidad Definida para el Paquete';
         lp_cargar_error(v_error);
    end;

    --Validar si Tiene Debito Automatico
    if v_error is null then
       if r_ctaTar.Deb_Automatico != 'S' and nvl(v_es_solicitado,'N') = 'N' then
           v_error := 'La tarjeta seleccionada debe Tener Débito Automatico';
           lp_cargar_error(v_error);
       end if;
    end if;

end lp_val_tarjeta;

--Validar Cuenta Combinada
procedure lp_val_cta_combinada is
  v_cant_av number;
  v_cant_cc number;
  v_count   number;
  v_cta_av  ge_cuentas.nro_cuenta%type;
  v_cta_cc  ge_cuentas.nro_cuenta%type;
  v_error   varchar2(100);
begin

  select count(1),max(t.nro_cuenta)
    into v_cant_av,v_cta_av
    from ge_paq_cuentas t
   where t.cod_paquete = p_cod_paquete
     and t.cod_persona = p_cod_persona
     and t.nro_secuencia = p_nro_secuencia
     and t.cod_modulo = 3
     and t.cod_modalidad = 31;

  select count(1),max(t.nro_cuenta)
    into v_cant_cc,v_cta_cc
    from ge_paq_cuentas t
   where t.cod_paquete = p_cod_paquete
     and t.cod_persona = p_cod_persona
     and t.nro_secuencia = p_nro_secuencia
     and t.cod_modulo = 4
     and t.cod_modalidad = 41;

   if nvl(v_cant_av,0)=1 and nvl(v_cant_cc,0)=1 then
     select count(1)
       into v_count
       from cc_cta_combinadas c
      where c.nro_cta_cte = v_cta_cc
        and c.nro_cta_ahorro = v_cta_av;

     --No estan Combinadas todavia
     if nvl(v_count,0) = 0 then
       --Verificar que no esten combinadas a Otras Cuentas
       select count(1)
         into v_count
         from cc_cta_combinadas c
        where (c.nro_cta_cte = v_cta_cc or c.nro_cta_ahorro = v_cta_av);

        if nvl(v_count,0) > 0 then
            v_error := 'Cta. Corriente/Caja de Ahorro vinculada a una Cuenta no incluida en el Paquete.Verifique';
           lp_cargar_error(v_error);
        end if;
     end if;
   end if;

end lp_val_cta_combinada;

--Validar que la cuenta ya no esté incluida en un paquete
procedure lp_val_paq_cuenta is
   v_cod_persona  ge_paq_cuentas.cod_persona%type;
   v_des_paquete  ge_paquetes.descripcion%type;
   v_cod_paquete  ge_paquetes.cod_paquete%type;
   v_error        varchar2(100);
begin
   begin
      select t.cod_persona, p.descripcion
        into v_cod_persona, v_des_paquete
        from ge_paq_cuentas t, ge_paquetes p
       where t.cod_paquete = p.cod_paquete
         and t.nro_cuenta = pag_cta.g_ctas.nro_cuenta;
   exception
      when no_data_found then
         null;
      when dup_val_on_index then
         if p_cod_persona = v_cod_persona then
            v_error := 'La Cuenta ya está activa para el Paquete '
                    || v_cod_paquete || '-' || v_des_paquete;
            lp_cargar_error(v_error);
         else
            v_error := 'La Cuenta ya está activa en el Paquete del Cliente ' || v_cod_persona;
            lp_cargar_error(v_error);
         end if;
   end;

end lp_val_paq_cuenta;

--Validar que la cuenta no tenga movimientos pendientes del contrato anterior 
--DYDMR-9358 IEC02 - Exoneraciones de Movimientos Pendientes
procedure lp_val_mov_pendientes(p_nro_cuenta varchar2 default null) is
   v_error        varchar2(100);
   CURSOR mov_pendientes is
		select a.nro_cuenta, count(1) cantidad
			from ge_paq_cuentas a,
			     ge_mov_pendientes b  
			where a.nro_cuenta=b.nro_cuenta
			    and b.estado = 'I'
					and a.cod_persona = p_cod_persona
					and a.cod_paquete = p_cod_paquete
					and a.nro_cuenta = nvl(p_nro_cuenta,a.nro_cuenta)
		group by a.nro_cuenta;
begin
   begin
      FOR cta IN mov_pendientes LOOP
        v_error := v_error || 'Cta. '||cta.nro_cuenta|| ' con movimientos pendientes.Verifique.'||CHR(13);
	    END LOOP;
   exception
      when no_data_found then
         null;
   end;
   lp_cargar_error(v_error);
end lp_val_mov_pendientes;
	
      
      
      

-------------------------------------------
--         BLOQUE PRINCIPAL              --
-------------------------------------------

begin

     g_error := null;
    if p_accion != 'C' then --Solo si no se cancela el paquete hace todas las verificaciones
     --Si no se paso la cuenta como parametro es una Validación Global
     if p_nro_cuenta is null then
       --lp_val_cant_productos;
       lp_val_mov_pendientes;
       lp_can_pro_paquetes;
       lp_val_intervinientes;
       lp_val_cta_combinada;
     else
        --Traer Datos de la Cuenta
        pag_cta.g_ctas := null;
        pag_cta.pr_obt_cuenta(p_nro_cuenta);
        
        lp_val_mov_pendientes(p_nro_cuenta);
        lp_val_paq_cuenta;
        --Validar por Módulo
        --if pag_cta.g_ctas.cod_modalidad = 31 then
        if pag_cta.g_ctas.cod_modulo = 3 then
           lp_val_cta_ahorro;
        elsif pag_cta.g_ctas.cod_modalidad = 41 then
           lp_val_cta_corriente;
        elsif pag_cta.g_ctas.cod_modulo = 5 then
           lp_val_tarjeta;
        else
           g_error := 'Módulo de Cuenta no Válido('||pag_cta.g_ctas.cod_modalidad||'), debe ser AHORRO, CUENTA CORRIENTE o TARJETA';
        end if;
     end if;
    else
     if p_nro_cuenta is null then
       lp_val_mov_pendientes;
     else
       lp_val_mov_pendientes(p_nro_cuenta);
     end if;
    end if;
     --Asignar Mensaje de Error
     p_error := g_error;

end prg_ver_paq_cuentas;
/

