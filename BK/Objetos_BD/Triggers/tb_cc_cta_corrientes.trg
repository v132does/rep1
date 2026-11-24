CREATE OR REPLACE TRIGGER IT.TB_CC_CTA_CORRIENTES
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CTA_CORRIENTES
 FOR EACH ROW
DECLARE
v_cod_persona      ba_personas.cod_persona%type;
v_afe_debito       varchar2(1) default 'N';
/* Obtener estado de la verificacion de la cuenta. */
FUNCTION LF_OBT_EST_VERIFICAC
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
   v_est_verificacion ge_cuentas.est_verificacion%type;

/* Obtener estado de la verificacion de la cuenta. */
FUNCTION LF_OBT_EST_VERIFICAC
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_est_verificacion ge_cuentas.est_verificacion%type;
BEGIN
   select nvl(est_verificacion,'X')
   into v_est_verificacion
   from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
   return v_est_verificacion;
exception
   when others then
     raise_application_error(-20000,
     'Rec.Cta. '||sqlerrm);
END;
function fu_obt_max_fec_apertura return date is
   v_can_dias number(5) := 0;
   v_fec_actual date;
begin
   select max(can_dias)
     into v_can_dias
     from ge_ret_monedas
    where cod_moneda = :new.cod_moneda;
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
   v_fec_actual := pag_cal.FU_OBT_FEC_FIN_RET(v_fec_actual, :new.cod_oficina, v_can_dias);
   Return v_fec_actual;
Exception
   When NO_DATA_FOUND Then
      v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      Return v_fec_actual;
end fu_obt_max_fec_apertura;

--

BEGIN
   if inserting or updating then
      if :new.reg_firma is null and inserting then
         raise_application_error(-20000, 'Regimen de Firma no puede ser nulo');
      end if;
      -- Hace la verificacion de la fecha de apertura.
      if  :new.fec_apertura <> :old.fec_apertura
      and :new.fec_apertura > fu_obt_max_fec_apertura Then
         raise_application_error(-20000, 'La fecha de Apertura no puede ser mayor al dia: '||to_char(fu_obt_max_fec_apertura, 'DD/MM/RRRR'));
      end if;
      if :new.cod_sub_modalidad not in (19) then
        If  (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and inserting) or
            (:new.fec_apertura < pag_cal.FU_OBT_FEC_ACTUAL(3) and :new.fec_apertura <> :old.fec_apertura and updating) Then
           raise_application_error(-20000, 'La fecha de Apertura no puede ser menor a hoy');
        End if;
      end if;
      -- Hasta aqui la verificacion de la fecha de apertura.
      /*if :new.cod_oficina in (11,12,51) then
         raise_application_error(-20000, 'Oficina no habilitada para Cuentas.');
      end if;*/
   end if;

   if updating then
      if  lf_obt_est_verificac(:new.nro_cuenta) = 'V' and :old.estado not in ('X','A')
      and (nvl(:new.mto_apertura,0) <> nvl(:old.mto_apertura,0)
        or :new.fec_apertura <> :old.fec_apertura
        or :new.cod_moneda <> :old.cod_moneda) then
        --- Si la cuenta se encuentra verificada no deben modificarse dichos campos
        raise_application_error(-20000,
        'No puede modificar datos de cuentas verificadas');
      end if;


      --Control nuevo para impedir que se cancelen cuentas que estan como cuenta debito automatico para 
      --tarjetas, prestamos, solicitudes, cajas de seguridad o certificados de deposito de ahorro
      if :new.estado <> :old.estado AND :new.estado in ('C', 'P') and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then 
         if fug_val_deb_relacionada(:new.nro_cuenta) = 'S' then
            raise_application_error(-20000, 'La cuenta esta relacionada a Débitos Automáticos. Verifique');
         end if;             
      end if;  
      
      -- Verifica si el Cliente o la Cta. tiene Inhibición que no permita realizar débito BSEVOCORE-147
	   /* if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then ---se comenta el bloque por error en el cierre del 13-01-2020
        if :new.sal_total < :old.sal_total then
          v_cod_persona :=fug_obt_cli_principal(:new.nro_cuenta);
          v_afe_debito  := fug_obt_val_parcausal('AFE_DEB_CUENTA',v_cod_persona, :new.nro_cuenta);
          if nvl(v_afe_debito,'N') = 'S' then
            raise_application_error(-20000,'Inhibición del Cliente Principal o Vinculados a la Cuenta no permite realizar Débito');
          end if;
        end if;
      end if; */
    end if;
   --Control temporal acordado con Alice/JCLG 20061130
   /*If :new.fre_extracto <> 'M' Then
      raise_application_error(-20000, 'Frecuencia de Extracto debe ser Mensual');
   End if;*/ --COMENTARIZADO POR CAROLINA SANCHEZ(SIMGIA)

END;
/

