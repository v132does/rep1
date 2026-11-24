CREATE OR REPLACE TRIGGER IT.tb_ge_cta_clientes
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."GE_CTA_CLIENTES"
 FOR EACH ROW
--https://itti-digital.atlassian.net/browse/NVB-3811
DECLARE
   v_ins_vinculos_nov varchar2(1) default 'N';
   rv_scvno        sb_cta_vinculos_nov%rowtype;
   v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
   v_usu_mod_unipersonal ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('USU_MOD_UNIPERSONAL'), 'X');
/* Verificar si la persona es cliente. */
FUNCTION LF_VER_CLIENTE
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN BOOLEAN;
   v_cantidad number(05);
   --v_existe_inhibicion varchar2(01) := 'N';
   v_error varchar2(5):= 0;
   v_mens  varchar2(4000):= null;

/* Verificar si la persona es cliente. */
FUNCTION LF_VER_CLIENTE
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN BOOLEAN
 IS
v_dummy number(01);
BEGIN
   select 1 into v_dummy
     from ge_clientes
    where cod_persona = p_cod_persona;
   return true;
exception
   when no_data_found then
      return false;
   when too_many_rows then
      return true;
END;

/* Verificar si la persona tiene tarjetas de debito para la cuenta con estados diferentes a (16)ANULADAS y/0 (1)RECHAZADAS. */
FUNCTION LF_VER_TAR_DEBITO
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE,
  P_NRO_CUENTA  in GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN boolean;

FUNCTION LF_VER_TAR_DEBITO
 (P_COD_PERSONA IN GE_CLIENTES.COD_PERSONA%TYPE,
  P_NRO_CUENTA  in GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN BOOLEAN
 IS
v_dummy number(01);
BEGIN
   select 1
     into v_dummy
     from ah_tar_debitos
    where cod_persona = p_cod_persona
      and cod_est_solicitud not in (1,16)
      and nro_cuenta = p_nro_cuenta;
   return true;
exception
   when no_data_found then
      return false;
   when too_many_rows then
      return true;
END;

BEGIN
if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPELICTA' then -- eliminacion de cuentas
   IF inserting then
       -- se excluye la validacion de firmante si la creacion de cda procede de la app - AIU-2087
       if nvl(fug_obt_pardinamico('USU_CDA_APP',:new.cod_modulo,:new.cod_modalidad),'X') = USER then
         v_error := 0;
       else
         v_error:= FUG_VER_FIRMANTE(:new.cod_persona,:new.cod_modulo,:new.cod_modalidad, null, :new.cod_oficina,v_mens);
       end IF;
       If v_error <> 0 and :new.cod_modulo <> 5 then -- se excluye el modulo 5 para que permita la insercion proveniente de Bancard. DYDMR-10422
         --Agregado para Identificar Clientes de Relacion D=Cedentes que tienen Inhibicion--
         --dydmr-1522--
         if :new.relacion = 'D' then
            v_mens := v_mens||'-'||fug_obt_des_ent_persona(:new.cod_persona,'CO');
         end if;
         raise_application_error(-20000,v_mens);
      End if;
      ---- Solo puede ingresarse una relacion Principal y debe ser el primero
      select nvl(count(*),0)
      into v_cantidad
      from ge_cta_clientes
      where nro_cuenta = :new.nro_cuenta;
      if :new.relacion <> 'P' and v_cantidad = 0 then
         raise_application_error(-20000,
         'La primera relacion con la cuenta debe ser la PRINCIPAL');
      end if;
      if :new.relacion = 'P' and v_cantidad <> 0 then
         raise_application_error(-20000,
         'Solo puede existir una relacion PRINCIPAL para la cuenta');
      end if;

      --- Verificar que si es relacion principal sea un cliente
      if :new.relacion = 'P' and not lf_ver_cliente(:new.cod_persona) then
         raise_application_error(-20000,
         'Relacion Principal debe pertenecer a un cliente');
      end if;
      if :new.cod_modulo = 3 and :new.cod_modalidad = 31 then
         begin
           select cod_sub_modalidad
             into v_cod_sub_modalidad
             from ah_cta_vistas
            where nro_cuenta = :new.nro_cuenta;
         exception
           when others then
             v_cod_sub_modalidad := 1;
         end;
         if :new.relacion <> 'P' and v_cod_sub_modalidad = 26 then
            raise_application_error(-20000, 'La Cuenta B?sica s?lo puede tener un cliente principal.');
        end if;
      end if;
   elsif deleting then
      if :old.relacion = 'P' then
           raise_application_error(-20000,
           'Eliminacion del Principal no permitida - Modifique');
      end if;

   END IF;
   If updating then
     If :new.relacion <> :old.relacion and :old.relacion = 'P' then
       if not ( nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'), 'X') =  nvl(fug_obt_naturaleza(:new.cod_persona),'N') and
        (instr(v_usu_mod_unipersonal, '#'||user||'#' ) > 0) ) then
             --NVB-3704 Solo debe saltar la validación si es una empresa con naturaliza distinta a la unipersonal
         raise_application_error(-20000,
           'Modificacion de Relacion Principal no permitida');
       end if;
     End if;
     if :new.cod_persona <> :old.cod_persona and lf_ver_tar_debito(:old.cod_persona,:old.nro_cuenta) then
       raise_application_error(-20000,
         'Modificacion no permitida - Cuenta tiene Tarjetas de Debito');
     end if;
     -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013
     -- Requerimiento: DYDMR-1806.
     -- Fecha: 28/04/2015.
     -- Requerimiento: CNFDEEVO-47.
     -- Fecha: 09/07/2016.
     IF NVL(fug_obt_paradicional(:new.nro_cuenta,'CTA_PUNTAS_TESORERIA'),'N') = 'N' THEN
        if :new.cod_oficina != FUG_OBT_OFI_OFICIAL(:new.Cod_Persona) and :new.relacion = 'P' then
           raise_application_error(-20000,'La Oficina de la cuenta debe llevar la oficina del Oficial: '||fue_obt_des_oficina(FUG_OBT_OFI_OFICIAL(:new.Cod_Persona))||' ('||FUG_OBT_OFI_OFICIAL(:new.Cod_Persona)||')');
        End If;
     END IF;
   End if;
end if;
   IF deleting OR inserting THEN
      v_ins_vinculos_nov := 'S';
      IF inserting AND :new.relacion <> 'A' THEN
         IF fus_ver_crc_vinculos(:new.cod_persona, :new.relacion, :new.nro_cuenta) = 'S' THEN
            rv_scvno.evento := 'V';
            rv_scvno.cod_persona := :new.cod_persona;
            rv_scvno.relacion := :new.relacion;
            rv_scvno.nro_cuenta  := :new.nro_cuenta;
            rv_scvno.cod_modulo  := :new.cod_modulo;
         ELSE
            rv_scvno.evento := NULL;
         END IF;
      ELSIF deleting AND :old.relacion <> 'A' THEN
         IF fus_ver_crc_vinculos(:old.cod_persona, :old.relacion, :old.nro_cuenta) = 'S' THEN
            rv_scvno.evento := 'D';
            rv_scvno.relacion    := :old.relacion;
            rv_scvno.cod_persona := :old.cod_persona;
            rv_scvno.nro_cuenta  := :old.nro_cuenta;
            rv_scvno.cod_modulo  := :old.cod_modulo;
         END IF;
      END IF;
   END IF;
   IF nvl(v_ins_vinculos_nov, 'N') = 'S' AND rv_scvno.evento IS NOT NULL THEN
      rv_scvno.fecha       := to_date(to_char(SYSDATE, 'DDMMYYYY') ||
                                      pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS')),
                                      'DDMMYYYY HH24:MI:SS');
      rv_scvno.hora        := pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS'));
      BEGIN
         INSERT INTO sb_cta_vinculos_nov
            (fecha, hora, nro_cuenta, cod_persona, evento, relacion, cod_modulo)
         VALUES
            (rv_scvno.fecha, rv_scvno.hora, rv_scvno.nro_cuenta, rv_scvno.cod_persona,
             rv_scvno.evento, rv_scvno.relacion, rv_scvno.cod_modulo);
      EXCEPTION
         WHEN dup_val_on_index THEN
            NULL;
      END;
  END IF;

   IF inserting AND :new.relacion = 'P' THEN
     IF fua_es_cta_basica(:new.nro_cuenta) = 'S' and fug_obt_est_cuenta(:new.nro_cuenta) = 'A' THEN
       prg_ins_doc_catastro (:new.cod_persona,:new.nro_cuenta);
     END IF;
   END IF;

END;
/
