CREATE OR REPLACE FUNCTION IT.FUG_OBT_PER_CLIENTE (p_cod_persona varchar2,
                                                  p_cod_modulo  number default null)
return varchar2 is
  v_resultado   varchar2(250);
  v_existe      varchar2(1);
  v_tipo        varchar2(1);
  v_naturaleza  ba_per_juridicas.naturaleza%type;
  v_est_civil   ba_per_fisicas.est_civil%type;
  v_cantidad    number := 0;
  v_perfil      varchar2(1) := 'N';
  v_vinculo     varchar2(1) := 'N';
  v_exi_acc_por varchar2(1);
  v_ind_emi_acc_portador ba_acc_portador.ind_acc_portador%type;
  v_cap_suscrito ba_acc_portador.cap_suscrito%type;
  v_can_acc_portador ba_acc_portador.can_acc_portador%type;
  v_cap_integrado ba_acc_portador.cap_integrado%type;
  v_can_acc_nominativa ba_acc_portador.can_acc_nominativa%type;
  v_cod_moneda ba_acc_portador.cod_moneda%type;
BEGIN
   select p.tipo
     into v_tipo
     from ba_personas p
    where p.cod_persona = p_cod_persona;

   If p_cod_modulo not in (5,6) then -- BSEVOCORE-1069
     begin
        -- Origen de Fondos
        select 'S'
          into v_existe
          from cr_inf_fondos cof
         where cod_persona = p_cod_persona
           and ( nvl(cof.fon_propio, 'N') = 'S'
                 or nvl(cof.fon_transferencias,'N') = 'S'
                 or nvl(cof.fon_salario,'N')     = 'S'
                 or nvl(cof.fon_prestamos,'N')   = 'S'
                 or nvl(cof.fon_vta_activos,'N') = 'S'
                 or nvl(cof.fon_ren_financieras,'N') = 'S'
                 or nvl(cof.fon_herencia,'N')    = 'S'
                 or nvl(cof.fon_ahorro,'N')      = 'S'
                 or cof.fon_otros is not null );
     exception
        when no_data_found then
           v_resultado := '-Origen de Fondos ';
           v_perfil  := 'S';
     end;
   End if;
   -- Para proceder a controlar estos Perfiles, el módulo pasado como parámetro debe estar seteado a S en el parámetro dinámico.
   if nvl(fug_obt_pardinamico('MOD_VER_PERFILES', p_cod_modulo), 'N') = 'S' then
      begin
          -- Propósito de la cuenta
          select 'S'
          into v_existe
          from cr_inf_fondos cpc
          where cpc.cod_persona = p_cod_persona
           and ( nvl(cpc.pro_ingresos,'N')   = 'S'
                 or nvl(cpc.pro_ahorros,'N') = 'S'
                 or nvl(cpc.pro_ven_alq,'N') = 'S'
                 or nvl(cpc.pro_gas_operativos,'N')= 'S'
                 or cpc.pro_otros is not null );
      exception
         when no_data_found then
            v_resultado := v_resultado || '-Propósito de la cuenta ';
            v_perfil  := 'S';
      end;
      
      begin
          -- Actividades Esperadas
          select 'S'
          into v_existe
          from cr_act_esperadas cae
          where cae.cod_persona = p_cod_persona
          and rownum = 1;
      exception
         when no_data_found then
            v_resultado := v_resultado||'-Actividades Esperadas ';
            v_perfil  := 'S';
      end;

      begin
          -- Controla si el cliente ingresó  PEP -> S/N
           Select 'S'
           into v_existe
           from CR_INF_FONDOS cif
           where cif.cod_persona = p_cod_persona
           and   cif.pep is not null--verifica que la Persona tenga cargada el Valor de S/N en el campo PEP
           and   rownum = 1;
      exception
         when no_data_found then
            v_resultado := v_resultado || '-Ingresar PEP (Si/No)';
            v_perfil  := 'S';
      end; 
  /**A pedido del usuario al dar de alta  un producto el sistema solo debe obligar el ingreso
     de Origen de Fondos, Propósito de la Cuenta y Actividades Esperadas.**/
  /*
      begin
          -- Tipo de Operaciones
          select 'S'
          into v_existe
          from cr_per_tip_operaciones pto
          where pto.cod_persona = p_cod_persona
          union all
          select 'S'
          from cr_inf_fondos cif
          where cif.cod_persona = p_cod_persona
          and cif.tip_ope_otros is not null;
      exception
          when too_many_rows then
              v_existe := 'S';
          when no_data_found then
              v_resultado := v_resultado||'-Tipo de Operaciones ';
      end;

      if v_tipo = 'F' then
        begin
            -- Ingresos persona fisica
            select 'S'
              into v_existe
              from cr_per_ing_egresos pie, cr_inf_laborales lab
             where pie.cod_persona = p_cod_persona
               and pie.ing_egreso = 'I'
               and lab.cod_persona = pie.cod_persona
               and lab.cod_direccion is not null
               and pie.importe <> 0
               and rownum = 1;
         exception when no_data_found then
           v_resultado := v_resultado || '-Laborales ';
         end;
       else
         begin
            -- Ingresos persona juridica
            select 'S'
              into v_existe
              from cr_per_ing_egresos pie
             where pie.cod_persona = p_cod_persona
               and pie.ing_egreso = 'I'
               and pie.importe <> 0
               and rownum = 1;
            exception when no_data_found then
              v_resultado := v_resultado || '-Ingresos ';
         end;
      end if;
  */
   end if;
--cod_circuito = 5 y 38
    declare
    v_cod_circuito wf_circuitos.cod_circuito%type;
    v_tip_circuito wf_circuitos.cod_tip_circuito%type;
   begin
    begin
      Select w.cod_circuito, w.cod_tip_circuito
        into v_cod_circuito, v_tip_circuito
      from wf_circuitos w
      where w.Cod_Tip_Circuito in ('5','7','38')
        and w.cod_persona = p_cod_persona
        and w.estado      = 'E';
   exception
      when others then
        null; -- si no encuentra el dato no cargar la variable v_resultado
		      -- y deberia pasar de largo esta seccion

    end;
    
    IF v_cod_circuito IS NOT NULL THEN
      v_resultado := ' Verificar Workflow numero:'|| v_cod_circuito || ' Tipo:'||v_tip_circuito;
    ELSE
      v_resultado := null;
    END IF;
    
       return v_resultado;

   end;
    
   if v_perfil  = 'N' then
      -----------------
      -- Verifico los vínculos(naturaleza y estado civil) PJ Y PF.
      begin
         select naturaleza, 'J'
           into v_naturaleza, v_tipo
           from ba_per_juridicas
          where cod_persona = p_cod_persona;
      exception
         when others then
            begin
               select est_civil, 'F'
                 into v_est_civil, v_tipo
                 from ba_per_fisicas
                where cod_persona = p_cod_persona;
            exception
               when others then
                  null;
            end;
      end;
      if v_tipo = 'J' then
         if v_naturaleza in ('SA','SRL','SEPA') then
            begin
               select count(*)
                 into v_cantidad
                 from ba_vinculos a
                where a.cod_persona = p_cod_persona
                  and a.tipo in ('DI','AC','S','P');
            exception
               when others then
                  v_cantidad := 0;
            end;
            if v_cantidad < 1 then
               v_resultado := 'Para la apertura de Productos o Servicios la Persona debe tener registrado un Vínculo tipo: (Accionista, Director, Socio, Presidente).';
               v_vinculo  := 'S';
            end if;
         end if;
         if instr(','||fug_obt_pardinamico('NAT_ACC_PORTADOR')||',',''''||v_naturaleza||'''') > 0 then
           begin
              select 'S', ind_acc_portador, cod_moneda, cap_suscrito, can_acc_portador, cap_integrado, can_acc_nominativa
                into v_exi_acc_por, v_ind_emi_acc_portador, v_cod_moneda, v_cap_suscrito, v_can_acc_portador, v_cap_integrado, v_can_acc_nominativa
                from ba_acc_portador
               where cod_persona = p_cod_persona;
           exception
             when others then
               v_exi_acc_por := 'N';
               v_ind_emi_acc_portador := null;
               v_cod_moneda := null;
               v_cap_suscrito := null;
               v_can_acc_portador := null;
               v_cap_integrado := null;
               v_can_acc_nominativa := null;
           end;

           if nvl(fug_obt_pardinamico('MOD_CON_ACC_PORTADOR', p_cod_modulo), 'N') = 'S' then
             if nvl(v_exi_acc_por, 'N') = 'N' then
                v_resultado := 'Para la apertura de Productos o Servicios debe estar cargado en la Carpeta General de la Persona/Personales los siguientes datos: Acc. al Portador, Capital Suscrito, Cant. Acc. Port., Capital Integrado, Cant. Acc. Nom.';
             else
               if nvl(v_ind_emi_acc_portador, 'N') = 'S' and
                 (v_cod_moneda is null or nvl(v_cap_suscrito,0) = 0 or nvl(v_can_acc_portador,0) = 0 or nvl(v_cap_integrado, 0) = 0) then
                  v_resultado := 'Para la apertura de Productos o Servicios debe estar cargado en la Carpeta General de la Persona/Personales los siguientes datos: Acc. al Portador, Moneda, Capital Suscrito, Cant. Acc. Port., Capital Integrado';
               elsif nvl(v_ind_emi_acc_portador, 'N') = 'N' and
                 (v_cod_moneda is null or nvl(v_cap_suscrito,0) = 0 or nvl(v_can_acc_nominativa,0) = 0 or nvl(v_cap_integrado, 0) = 0) then
                  v_resultado := 'Para la apertura de Productos o Servicios debe estar cargado en la Carpeta General de la Persona/Personales los siguientes datos: Acc. al Portador, Moneda, Capital Suscrito, Cant. Acc. Nominativa, Capital Integrado';
               end if;
             end if;
           end if;
         end if;
      else -- física
         if v_est_civil = 'C' then
            begin
               select count(*)
                 into v_cantidad
                 from ba_vinculos a
                where a.cod_persona = p_cod_persona
                  and a.tipo = 'E'; --CONYUGE O ESPOSO/A
            exception
               when others then
                  v_cantidad := 0;
            end;
            if v_cantidad != 1 then
               v_resultado := 'Para la apertura de Productos o Servicios la Persona debe tener registrado el Vínculo tipo Cónyuge.';
               v_vinculo  := 'S';
            end if;
         end if;
      end if;
   end if;

   if v_resultado is not null and v_perfil  = 'S' then
      v_resultado := 'Debe cargar los siguientes datos del Perfil del Cliente:'||v_resultado;
   elsif v_resultado is not null and v_vinculo  = 'S' then
      v_resultado := v_resultado;
   elsif v_resultado is null then
      v_resultado := 'S'; -- La persona tiene cargado los datos requeridos
   end if;

  return v_resultado;

END;
/

