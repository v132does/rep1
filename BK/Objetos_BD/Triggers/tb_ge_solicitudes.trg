CREATE OR REPLACE TRIGGER IT.TB_GE_SOLICITUDES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_SOLICITUDES
 FOR EACH ROW

DECLARE
  v_cod_tip_canal       ge_tip_canales.cod_tip_canal%type;
  v_cantidad            number(10) := 0;
  v_cod_tip_can_ignorar varchar2(1000);
/* Verificar datos de deudores. */
PROCEDURE LP_VER_DAT_DEUDORES
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_PERSONA IN GE_SOLICITUDES.COD_PERSONA%TYPE
 );
/* Verificar la verificaciones de las referencias de la solicitud. */
PROCEDURE LP_VER_VERIFICACION
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_PERSONA IN GE_SOLICITUDES.COD_PERSONA%TYPE
 );
/* Generar codeudores de la solicitud de préstamo. */
PROCEDURE LP_GEN_COD_SOLICITUD
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_NRO_SOL_PRESTAMO IN GE_SOLICITUDES.NRO_SOL_PRESTAMO%TYPE
 ,P_MONTO IN GE_SOLICITUDES.MONTO%TYPE
 );
PROCEDURE LP_INS_CLIENTE;

v_nro_solicitud       ge_solicitudes.nro_solicitud%type;
v_lin_min_tarjeta     ge_solicitudes.mto_limite%type;
v_lin_max_tarjeta     ge_solicitudes.mto_limite%type;
v_pla_max_solicitud   ge_solicitudes.plz_meses%type;
v_can_dia_atraso      number(10);
--variables para validación de campañas
v_estado  VARCHAR2(1) := 'N';
v_motivo VARCHAR2(2000);
---------------------------------------
Cursor cuentas is select ct.cod_modulo, ct.cod_modalidad, ct.cod_moneda, ct.dia_atraso
                    from ge_cuentas ct, ge_cta_clientes cc
                   where ct.nro_cuenta = cc.nro_cuenta
                     and not exists (Select '1'
                                     from ge_est_cuentas es
                                     where es.cod_modulo = ct.cod_modulo
                                       and es.cod_modalidad = ct.cod_modalidad
                                       and es.estado = ct.estado
                                       and es.activo = 'N')
                     and cc.relacion = 'P'
                     and cc.cod_modulo in (5, 6)
                     and cc.cod_persona = :new.cod_persona;

/* Verificar datos de deudores. */
PROCEDURE LP_VER_DAT_DEUDORES
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_PERSONA IN GE_SOLICITUDES.COD_PERSONA%TYPE
 )
 IS
-- Cursor de personas de la solicitud
   cursor c_per_sol is
   select p.cod_persona epers_cod_persona, 'DEUDOR' tipo, p.tipo epers_tipo
   from ba_personas p
   where p.cod_persona = p_cod_persona
   union all
   select p.cod_persona, 'CODEUDOR', p.tipo
   from ge_sol_codeudores g, ba_personas p
   where g.cod_persona = p.cod_persona
   and g.nro_solicitud = p_nro_solicitud
   order by tipo desc;
   r_epfis ba_per_fisicas%rowtype;
   r_epfco ba_per_fisicas%rowtype;
   r_epjur ba_per_juridicas%rowtype;
   r_edire ba_direcciones%rowtype;
   r_etele ba_telefonos%rowtype;
   r_ringr cr_per_ing_egresos%rowtype;
   r_rrefp cr_ref_personales%rowtype;
   v_cod_per_conyuge  ba_personas.cod_persona%type;
   v_inhibido varchar2(1) := 'N';
   v_tie_conyugue varchar2(1);
BEGIN
   for per in c_per_sol loop
      --- Recuperar datos de la persona
      if per.epers_tipo = 'F' then
         --- Persona física
         begin
            select * into r_epfis from ba_per_fisicas where cod_persona = per.epers_cod_persona;
         exception
            when no_data_found then
               raise_application_error(-20000,'Persona Física (Deudor) no registrada');
         end;
         if r_epfis.fec_nacimiento is null then
            raise_application_error(-20000, per.tipo||' sin fecha de nacimiento');
         else
            if (sysdate - r_epfis.fec_nacimiento)/365 < fug_obt_pardinamico('EDA_MIN_SOLICITUD') then
               raise_application_error(-20000, per.tipo||' No posee Edad Mínima suficiente para gestionar Solicitud');
            end if;
         end if;
         if r_epfis.cod_pai_nacionalidad is null then
            raise_application_error(-20000, per.tipo||' sin nacionalidad');
         end if;
         if r_epfis.cod_profesion is null then
            raise_application_error(-20000, per.tipo||' sin profesión');
         end if;
         if r_epfis.cod_tip_vivienda is null then
            raise_application_error(-20000, per.tipo||' sin tipo de vivienda');
         end if;
         -- Verifica que no este inhibido...
/*     Se hace el control en el programa...
          Begin
             Select 'S'
               into v_inhibido
               from ge_per_inhibidas i
              where i.cod_persona = per.epers_cod_persona;
         Exception
             When NO_DATA_FOUND Then
                  v_inhibido := 'N';
             When TOO_MANY_ROWS Then
                  v_inhibido := 'S';
         End;
         If v_inhibido = 'S' Then
            raise_application_error(-20000, per.tipo||' inhibido.');
         End If;*/
         if r_epfis.est_civil = 'C' then -- casada
            --- Recuperar datos del cónyuge
            begin
               select distinct decode(cod_persona, per.epers_cod_persona, cod_per_vinculo, cod_persona)
               into v_cod_per_conyuge
               from ba_vinculos
               where (cod_persona = per.epers_cod_persona
                   or cod_per_vinculo = per.epers_cod_persona)
                 and tipo = 'E';
            exception
               when no_data_found then
                 -- raise_application_error(-20000,
                 -- 'Conyuge no definido para persona '||per.tipo);
                 null;
               when too_many_rows then
                  raise_application_error(-20000,
                  'Cónyuge duplicado para persona '||per.tipo);
            end;
            --- Persona física del cónyuge
            If v_cod_per_conyuge is not null Then
            begin
               select * into r_epfco from ba_per_fisicas where cod_persona = v_cod_per_conyuge;
            exception
               when no_data_found then
                  raise_application_error(-20000,'Persona Física Cónyuge del '||per.tipo||' no registrada');
            end;
            End If;
            /* No hace falta obligar a que se carguen todos los datos...
            if r_epfco.fec_nacimiento is null Then
               raise_application_error(-20000,'Conyuge del '||per.tipo||' sin fecha de nacimiento');
            end if;
            if r_epfco.cod_pai_nacionalidad is null then
               raise_application_error(-20000,'Conyuge del '||per.tipo||' sin nacionalidad');
            end if;
            */
         end if;
      else
         --- Persona Juridica
         begin
            select * into r_epjur from ba_per_juridicas where cod_persona = per.epers_cod_persona;
         exception
            when no_data_found then
               raise_application_error(-20000,'Persona Jurídica '||per.tipo||' no registrada');
         end;
         if r_epjur.fec_apertura is null then
            raise_application_error(-20000, 'Fecha constitución del '||per.tipo||' no registrada');
         end if;
      end if;
      --- Verificar información dirección
      if per.tipo = 'DEUDOR' then
          begin
             select * into r_edire from ba_direcciones where cod_persona = per.epers_cod_persona and tipo = 'P' and rownum=1;
          exception
             when no_data_found then
                raise_application_error(-20000,'Dirección no definida para '||per.tipo);
          end;
          if r_edire.cod_barrio is null then
             raise_application_error(-20000,'Barrio no definido para '||per.tipo);
          end if;
      end if;
      --- Verificar teléfono
      begin
         v_tie_conyugue := 'N';
         Begin
         select 'S'
           into v_tie_conyugue
           from ba_vinculos b
          where b.cod_per_vinculo = per.epers_cod_persona
            and b.tipo = 'E';
         Exception
           When NO_DATA_FOUND then v_tie_conyugue := 'N';
           When TOO_MANY_ROWS Then v_tie_conyugue := 'S';
         End;
         if v_tie_conyugue = 'N' then
           select * into r_etele
             from ba_telefonos
            where cod_persona = per.epers_cod_persona
              and tipo = 'P';
         end if;
      exception
         when no_data_found then
            raise_application_error(-20000,'Teléfono no definido para '||per.tipo);
         when too_many_rows then null;
      end;
      --- Verificar ingresos
      begin
         select * into r_ringr from cr_per_ing_egresos where cod_persona = per.epers_cod_persona;
      exception
         when no_data_found then
            raise_application_error(-20000,'Ingresos no definidos para '||per.tipo);
         when too_many_rows then null;
      end;
      --- Verificar referencia personal
      if per.tipo = 'DEUDOR' then
      begin
         select * into r_rrefp from cr_ref_personales where cod_persona = per.epers_cod_persona;
      exception
         when no_data_found then
            raise_application_error(-20000,'Referencias personales no definidas para '||per.tipo);
         when too_many_rows then null;
      end;
      End If;
   end loop;
END;
/* Verificar la verificaciones de las referencias de la solicitud. */
PROCEDURE LP_VER_VERIFICACION
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_COD_PERSONA IN GE_SOLICITUDES.COD_PERSONA%TYPE
 )
 IS
v_cantidad number(05);
BEGIN
   select count(*)
   into v_cantidad
   from gv_sol_verificacion v
   where v.est_verificacion = 'N'
   and (v.cod_persona = P_cod_persona
    or exists (select 1 from ge_sol_codeudores c
               where c.cod_persona = v.cod_persona
                 and c.nro_solicitud = p_nro_solicitud));
   if v_cantidad > 0 then
      raise_application_error(-20000,
      'Existen referencias sin verificarse para los integrantes de la solicitud');
   end if;
END;
/* Generar codeudores de la solicitud de prestamo. */
PROCEDURE LP_GEN_COD_SOLICITUD
 (P_NRO_SOLICITUD IN GE_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_NRO_SOL_PRESTAMO IN GE_SOLICITUDES.NRO_SOL_PRESTAMO%TYPE
 ,P_MONTO IN GE_SOLICITUDES.MONTO%TYPE
 )
 IS
v_cantidad number(4) := 0;
--- Cursor de prestamos, solo si no es su cónyuge...
   CURSOR c_sol_codeudores IS
   select c.cod_persona
     from ba_vinculos v, ge_sol_codeudores c
    where c.nro_solicitud = p_nro_solicitud
      and v.cod_persona(+) = :new.cod_persona
      and v.tipo(+) = 'E'
      and v.cod_per_vinculo(+) != c.cod_persona;
BEGIN
   v_cantidad := 0;
   for scod in c_sol_codeudores loop
     v_cantidad := v_cantidad + 1;
     insert into pr_sol_garantias
        (nro_solicitud, nro_garantia,
         cod_garantia, mto_aplicado)
     values
        (p_nro_sol_prestamo, scod.cod_persona,
         2 /* Codeudores */, p_monto);
   end loop;
   If v_cantidad = 0 then
      -- Inserta a sola firma
     insert into pr_sol_garantias
        (nro_solicitud, nro_garantia,
         cod_garantia, mto_aplicado)
     values
        (p_nro_sol_prestamo, null,
         1 /* Codeudores */, p_monto);

   End If;
END;
PROCEDURE LP_INS_CLIENTE
 IS
v_existe_cliente varchar2(1) := 'N';
 v_cod_oficina ge_clientes.cod_oficina%type;
 v_oficial ba_usuarios.oficial%type;
 v_cod_usu_oficial ba_usuarios.cod_usu_supervisor%type;
BEGIN
   -- primero verifica si existe en ge_clientes...
   Begin
     Select 'S' into v_existe_cliente
       from ge_clientes
      where cod_persona = :new.cod_persona;
   Exception
      When NO_DATA_FOUND Then
          v_existe_cliente := 'N';
   End;
   if v_existe_cliente = 'N' and :new.cod_usu_promotor is not null Then
       select cod_oficina, oficial
         into v_cod_oficina, v_oficial
         from ba_usuarios
        where cod_usuario = :new.cod_usu_promotor;
       v_cod_usu_oficial := :new.cod_usu_promotor;
       If v_oficial = 'N' then
          v_cod_usu_oficial := fug_obt_pardinamico('COD_USU_OFI_DEFECTO',
                                 :new.cod_modulo,
                                 :new.cod_modalidad,
                                 :new.cod_moneda,
                                 v_cod_oficina);
       End if;
       insert into ge_clientes
           (cod_persona, cod_oficina, cod_usu_oficial,
            residente, cod_tip_deudor, cod_sec_contable)
       values
           (:new.cod_persona, v_cod_oficina, v_cod_usu_oficial,
            'S', 2, 'N');
   End If;
END LP_INS_CLIENTE;
BEGIN
   if inserting then
     --****inicio****--
     -- Controla que no tenga pendiente de Ingreso de Datos...
     v_cod_tip_can_ignorar := fug_obt_pardinamico('COD_TIP_CAN_IGNORAR',
                                                  :new.cod_modulo,
                                                  :new.cod_modalidad,
                                                  :new.cod_moneda,
                                                  null);
     If :new.cod_canal is not null Then
		   Select cod_tip_canal
		     into v_cod_tip_canal
		     from ge_canales
		    where cod_canal = :new.cod_canal;
     End If;
     If instr(v_cod_tip_can_ignorar, v_cod_tip_canal) = 0 Then
       Begin
         Select count(*)
      	   into v_cantidad
   	       from ge_canales c, ge_solicitudes s
       	  where cod_persona   = :new.cod_persona
       	    and cod_modulo    = :new.cod_modulo
   	        and nro_solicitud != nvl(:new.nro_solicitud,-1)
   	        and cod_estado not in ('RCH', -- Rechazado
                                   'DES', -- Desembolsado
                                   'TIA', -- Tarjeta ingresada en Administradora
                                   'ANU', -- Anulada
                                   'NEN'  -- No entregada
                                   )
            and c.cod_canal = s.cod_canal
            and instr(v_cod_tip_can_ignorar, c.cod_tip_canal) = 0;
 	          --
	    	    If v_cantidad > 0 Then
		   	      raise_application_error(-20000,'Esta persona posee Solicitud en curso. Verifique.');
		   	    End If;
	     Exception
	       When NO_DATA_FOUND Then
	         null;
	     End;
     End If;
    --****fin****--
      :new.mto_aprobado := :new.monto;
       if :new.cod_modulo = 5 then
            -- Debe verificar las líneas de aprobación de Tarjetas
            v_lin_min_tarjeta := fug_obt_pardinamico('LIN_MIN_TARJETA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
            v_lin_max_tarjeta := fug_obt_pardinamico('LIN_MAX_TARJETA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
            If :new.mto_aprobado not between v_lin_min_tarjeta and v_lin_max_tarjeta then
               raise_application_error(-20005,
                  'La línea debe estar entre '||TRIM(to_char(v_lin_min_tarjeta, '999,999,999,999'))||' y '||TRIM(to_char(v_lin_max_tarjeta, '999,999,999,999')));
            End If;
       elsif :new.cod_modulo = 6 then
            v_pla_max_solicitud := fug_obt_pardinamico('PLA_MAX_SOLICITUD', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
            If :new.plz_meses > v_pla_max_solicitud then
               raise_application_error(-20005,
                  'El plazo no puede ser superior a '||v_pla_max_solicitud||' meses.');
            End if;
       end if;
   end if;
   If updating and :new.monto != :old.monto then
      :new.mto_aprobado := :new.monto;
   End If;
   If updating then
       if :new.cod_modulo = 5 and :new.mto_aprobado != :old.mto_aprobado then
            -- Debe verificar las líneas de aprobación de Tarjetas
            v_lin_min_tarjeta := fug_obt_pardinamico('LIN_MIN_TARJETA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
            v_lin_max_tarjeta := fug_obt_pardinamico('LIN_MAX_TARJETA', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
            If :new.mto_aprobado not between v_lin_min_tarjeta and v_lin_max_tarjeta then
               raise_application_error(-20005,
                  'La línea debe estar entre '||TRIM(to_char(v_lin_min_tarjeta, '999,999,999,999'))||' y '||TRIM(to_char(v_lin_max_tarjeta, '999,999,999,999')));
            End If;
       elsif :new.cod_modulo = 6 and :new.plz_meses != :old.plz_meses then
          v_pla_max_solicitud := fug_obt_pardinamico('PLA_MAX_SOLICITUD', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null);
          If :new.plz_meses > v_pla_max_solicitud then
             raise_application_error(-20005,
                'El plazo no puede ser superior a '||v_pla_max_solicitud||' meses.');
          End if;
       end if;
   End If;
   --
   If inserting or updating then
      -- Controla la morosidad de la persona
      If :new.cod_estado not in ('RCH','ANU','RTE','PVC','NEN') Then
          for r_cuenta in cuentas loop
              if nvl(r_cuenta.dia_atraso,0) > fug_obt_pardinamico('DIA_ATR_SOLICITUD', :new.cod_modulo, :new.cod_modalidad, :new.cod_moneda, null) then
                 raise_application_error(-20006, 'El cliente posee atraso.');
                 exit;
              End if;
          end loop;
      End if;
      -- Validaciones para campañas
      PRP_VAL_CAM_SOLICITUDES ( :new.COD_CAMPANA,   :new.COD_PERSONA, 6,
                                :new.COD_MODALIDAD, :new.MONTO,
                                :new.COD_MONEDA,    :new.PLZ_MESES,
                                 v_estado,           v_motivo );
      If v_estado  = 'N' then
         raise_application_error(-20006, v_motivo);
      End if; 
   End if;
   --
   if UPDATING then
      if :new.cod_estado not in ('PID','PVT','PVD','PAN','PVC') and
        (:new.COD_PERSONA      <> :old.cod_persona
      or :new.COD_MODULO       <> :old.COD_MODULO
      or :new.COD_MODALIDAD    <> :old.COD_MODALIDAD
      or :new.MONTO            <> :old.monto
      or :new.COD_MONEDA       <> :old.COD_MONEDA
      or :new.FEC_SOLICITUD    <> :old.FEC_SOLICITUD
      or :new.COD_CANAL        <> :old.COD_CANAL
      or :new.COD_CAMPANA      <> :old.COD_CAMPANA
      or :new.COD_USU_PROMOTOR <> :old.COD_USU_PROMOTOR
      or :new.COD_USU_OFICIAL  <> :old.COD_USU_OFICIAL) then
         If (:new.COD_CANAL        <> :old.COD_CANAL
            or :new.COD_CAMPANA      <> :old.COD_CAMPANA
            or :new.COD_USU_PROMOTOR <> :old.COD_USU_PROMOTOR) and
            nvl(pae_cnf.g_programa, 'GMDATSOL') = 'GMDATSOL' Then
            null;
         Else
            raise_application_error(-20000,
            'Datos iniciales de la solicitud no pueden modificarse');
         End if;
      end if;
      if :new.cod_estado in ('APR','RCH','ANU','TIA','NEN') and
        (:new.mto_aprobado      <> :old.mto_aprobado
      or nvl(:new.mto_limite,0) <> nvl(:old.mto_limite,0)
      or nvl(:new.plz_meses,0)  <> nvl(:old.plz_meses,0)
      or nvl(:new.fec_vencimiento,trunc(sysdate)) <> nvl(:old.fec_vencimiento,trunc(sysdate))) then
         raise_application_error(-20000, 'Datos aprobados o rechazados de la solicitud no pueden modificarse');
      end if;
      :new.cod_est_anterior := :old.cod_estado;
      :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
      --- Verificar que la solicitud este bien cargada al pasar a estado de inicio de circuito
      if :old.cod_estado = 'PID' and :new.cod_estado = 'PVD' then
         --- No es necesario verificar datos de la solicitud porque son obligatorios
         --- Verificar datos del deudor
         lp_ver_dat_deudores(:new.nro_solicitud, :new.cod_persona);
      end if;
      -- Verifica si el usuario aprobo la solicitud y la suma de los limites de los
      -- usuarios que analizaron la solicitud
      -- mas el monto maximo de este usuario es menor que el monto de la solicitud,
      if :new.cod_estado = 'APR' and :old.cod_estado != 'APR' and (:new.mto_aprobado > (NVL(FUG_OBT_LIM_ACUMULAD(:new.nro_solicitud),0)+NVL(FUG_OBT_MTO_MAXIMO(user,:new.cod_moneda),0))) then
         :new.cod_estado := 'PLA';
      end if;
      if :new.cod_estado = 'RCH' then
         :new.tipo := null;
      end if;
      --- Validar estados
      if (:new.cod_estado = 'PVI' and :new.tipo not in ('P','L','A'))
      or (:new.cod_estado = 'PVC' and :new.tipo not in ('I','E'))
      or (:new.cod_estado not in ('PVI','PVC') and :new.tipo is not null) then
         raise_application_error(-20000,
         'Estado de la solicitud no corresponde al tipo de verificación');
      end if;
      if :new.COD_ESTADO = 'PVI' then
        if :new.TIPO is null or :new.TIPO = 'I' or :new.TIPO = 'E' then
           raise_application_error(-20000,
           'El Estado requiere un tipo (Particular, Laboral o Ambos)');
        end if;
      end if;
      if :new.COD_ESTADO = 'PVC' then
        if :new.TIPO not in ('I', 'E') then
           raise_application_error(-20000,
           'El Estado solo admite Tipo Interno, o Externo');
        end if;
      end if;
      IF :new.cod_estado IN ('APR','PLA') and :new.cod_estado <> :old.cod_estado then
         -- Verifica que el usuario no vuelva a modificar una solicitud que ya analizo.
         BEGIN
            SELECT COUNT(*)
              INTO v_nro_solicitud
              FROM GE_SOL_APROBACIONES
             WHERE NRO_SOLICITUD = :new.NRO_SOLICITUD
               AND COD_USUARIO = USER;
            if v_nro_solicitud > 0 then
               dbms_output.put_line(V_NRO_SOLICITUD);
               raise_application_error(-20000,
               'La solicitud ya fue analizada por el usuario '||user);
            end if;
         END;
      END IF;
      --- Validar aprobacion
/*      if  :new.cod_estado <> :old.cod_estado
      and :new.cod_estado IN ('APR','PAN') then
          lp_ver_verificacion(:new.nro_solicitud, :new.cod_persona);
      end if;*/
   end if;
   if updating then --- Esto se hace en el before porque se debe actualizar un dato de la tabla
      if :new.cod_estado = 'APR' and :new.cod_estado <> :old.cod_estado then
         -- Debe insertar en ge_clientes tanto para tarjetas como para prestamos.
         lp_ins_cliente;
         --
         if :new.cod_modulo = 6 then --- solo para creditos
            --- Cuando se aprueba la solicitud generar la propuesta
            PRP_GEN_SOLICITUD(:new.cod_persona, :new.cod_modalidad,
                              :new.cod_moneda, :new.mto_aprobado,
                              :new.plz_meses, 'S','N', null,
                              :new.fec_vencimiento, null, :new.cod_canal,
                              :new.cod_campana, null, :new.cod_usu_promotor);
            BEGIN
               select max(nro_solicitud)
                 into :new.nro_sol_prestamo
                 from pr_solicitudes
                where cod_persona = :new.cod_persona
                  and nro_solicitud = (select max(nro_solicitud)
                                         from pr_solicitudes
                                        where cod_persona = :new.cod_persona);
            exception
               when no_data_found then
                  raise_application_error(-20000,
                  'Solicitud de préstamo no generada');
               when others then
                  raise_application_error(-20000,
                  'Obt. Sol. Prest. '||sqlerrm);
            END;
            --- Generar los codeudores de la solicitud de prestamo
            --- OBS: Este procedimiento es especifico para el Circuito de solicitudes
            --- no se modifica el prp_gen_solicitud para que pueda ser utilizado desde
            --- otros modulos que requieran
            LP_GEN_COD_SOLICITUD(:new.nro_solicitud, :new.nro_sol_prestamo, :new.mto_aprobado);
        elsif :new.cod_modulo = 5 then --- Procesos para Tarjetas
          DECLARE
            v_ofi NUMBER(3);
          BEGIN
            BEGIN
              select cod_ofi_matriz
                into v_ofi
                from ge_par_generales;
            EXCEPTION
              when others then
                IF sqlcode <= -20000 THEN
                  RAISE;
                ELSE
                  v_ofi := 1;
                END IF;
            END;
            BEGIN
              insert into ta_solicitudes( nro_solicitud,
                                          cod_persona,
                                          cod_oficina,
                                          cod_modulo,
                                          cod_modalidad,
                                          cod_usu_promotor,
                                          fec_solicitud,
                                          cod_usu_oficial,
                                          fec_aprobacion,
                                          cod_causa,
                                          deb_automatico,
                                          nro_cta_debito,
                                          tip_cobro,
                                          nom_embozado,
                                          lin_sugerida,
                                          monto,
                                          puntaje,
                                          cod_estado,
                                          cod_est_sugerido,
                                          tas_int_adelanto,
                                          tas_financiacion,
                                          tas_mora,
                                          mto_min_pago,
                                          por_pag_minimo,
                                          tip_envio,
                                          referencia,
                                          nro_linea,
                                          observacion,
                                          cod_moneda,
                                          cod_campana,
                                          cod_canal,
                                          mto_aprobado )
                                  values( :new.nro_solicitud,
                                          :new.cod_persona,
                                          v_ofi, --cod_oficina
                                          :new.cod_modulo,
                                          :new.cod_modalidad,
                                          :new.cod_usu_promotor,
                                          :new.fec_solicitud,
                                          :new.cod_usu_oficial,
                                          :new.fec_cam_estado,
                                          NULL, --cod_causa
                                          'N', --deb_automatico
                                          NULL, --nro_cta_debito
                                          'M', --tip_cobro
                                          :new.nom_embozado,
                                          :new.lin_sugerida,
                                          :new.monto,
                                          :new.puntaje,
                                          :new.cod_estado,
                                          :new.cod_est_sugerido,
                                          NULL, --tas_int_adelanto
                                          NULL, --tas_financiacion
                                          NULL, --tas_mora
                                          NULL, --mto_min_pago
                                          NULL, --por_pag_minimo
                                          NULL, --tip_envio
                                          NULL, --referencia
                                          NULL, --nro_linea
                                          :new.observacion,
                                          :new.cod_moneda,
                                          :new.cod_campana,
                                          :new.cod_canal,
                                          :new.mto_aprobado );
            EXCEPTION
              when others then
                IF sqlcode <= -20000 THEN
                  RAISE;
                ELSE
                  RAISE_APPLICATION_ERROR( -20101, 'No se pudo replicar la solicitud para tarjetas ' || sqlerrm );
                END IF;
            END;
          END;
          BEGIN
            insert into ta_sol_adicionales( nro_solicitud,
                                            cod_persona,
                                            cod_estado,
                                            fec_aprobacion,
                                            fec_ingreso,
                                            cod_causa,
                                            nom_embozado,
                                            cod_usu_autoriza,
                                            cod_usu_promotor,
                                            cod_usu_oficial,
                                            observacion )
                                     select d.nro_solicitud,
                                            d.cod_persona,
                                            :new.cod_estado,
                                            :new.fec_cam_estado,
                                            :new.fec_solicitud,
                                            NULL, --cod_causa
                                            d.nom_embozado,
                                            NULL, --cod_usu_autoriza
                                            :new.cod_usu_promotor,
                                            :new.cod_usu_oficial,
                                            :new.observacion
                                       from ge_sol_adicionales d
                                      where nro_solicitud = :new.nro_solicitud;
          EXCEPTION
            when others then
              IF sqlcode <= -20000 THEN
                RAISE;
              ELSE
                RAISE_APPLICATION_ERROR( -20102, 'No se pudo replicar los datos adicionales para tarjetas ' || sqlerrm );
              END IF;
          END;
          BEGIN
            insert into ta_sol_garantias( nro_solicitud, 
                                          nro_garantia, 
                                          cod_garantia, 
                                          mto_aplicado )
                                   select c.nro_solicitud,
                                          c.cod_persona,
                                          2,
                                          :new.monto
                                     from ge_sol_codeudores c
                                    where c.nro_solicitud = :new.nro_solicitud
                                 UNION ALL
                                   select :new.nro_solicitud,
                                          :new.cod_persona, --cod_garantia
                                          1,
                                          :new.monto
                                     from dual
                                    where NOT EXISTS( select 1
                                                        from ge_sol_codeudores d
                                                       where d.nro_solicitud = :new.nro_solicitud );
          EXCEPTION
            when others then
              IF sqlcode <= -20000 THEN
                RAISE;
              ELSE
                RAISE_APPLICATION_ERROR( -20103, 'No se pudo replicar los datos de garantías para tarjetas ' || sqlerrm );
              END IF;
          END;
        end if;
      end if;
   end if;
END;
/

