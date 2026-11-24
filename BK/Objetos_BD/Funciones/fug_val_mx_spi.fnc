create or replace function it.fug_val_mx_spi(P_COD_SWIFT varchar2,
                                         -- p_tip_documento varchar2
                                          p_nro_documento varchar2,
                                          p_nro_cuenta varchar2,
                                          p_cod_moneda varchar2,
                                          p_monto   number,
                                          p_tipo varchar2) return varchar2
   is
   v_cod_mon_hab     varchar2(10) := fug_obt_pardinamico('SPI_COD_MON_HABILITADO');
   v_dias_inhabilitados varchar2(150) := fug_obt_pardinamico('SPI_DIAS_INHABILITADOS');
   v_mto_min number := NVL(fug_obt_pardinamico('SPI_MTO_MIN'),'0');
   v_mto_max number := NVL(fug_obt_pardinamico('SPI_MTO_MAX'),'5000000');
   v_spi_habilitado varchar2(1) := NVL(fug_obt_pardinamico('SPI_HABILITADO'),'N');
   v_spi_hab_24h varchar2(1) := NVL(fug_obt_pardinamico('SPI_HAB_24H'),'N');
   v_cod_moneda_cta ge_cuentas.cod_moneda%type;
   v_nro_cuenta     ge_cuentas.nro_cuenta%type;
   v_retorno varchar2(1):= 'S';
   V_ES_FERIADO    VARCHAR2(1);
   v_swift_patrocinador varchar2(20);
   v_spi_hor_inicial varchar2(20) := NVL(fug_obt_pardinamico('SPI_HOR_INICIAL'),'N');
   v_spi_hor_final varchar2(20) := NVL(fug_obt_pardinamico('SPI_HOR_FINAL'),'N');
begin
  IF v_spi_habilitado = 'S' THEN
    /*-- Valida si el horario esta habilitado 24h --*/
    IF v_spi_hab_24h = 'N' THEN
       begin
         select 'S'
         into   V_ES_FERIADO
         from   ba_feriados c
         where  c.fecha = TRUNC(SYSDATE);
         V_RETORNO :='N';
       exception
         WHEN NO_DATA_FOUND THEN
            IF instr(v_dias_inhabilitados,rtrim(ltrim(to_char(SYSDATE, 'DAY', 'NLS_DATE_LANGUAGE=SPANISH'))))>0 THEN
              V_RETORNO := 'N';
            ELSE
              IF TO_NUMBER(TO_CHAR(SYSDATE,'HH24MI')) 
                 NOT  between  to_number(v_spi_hor_inicial) and to_number(v_spi_hor_final) THEN
                 V_RETORNO := 'N';
              END IF;
            END IF;
       END;  
    END IF;
     /*-- Fin Valida horario habilitado 24h --*/
    IF p_monto NOT BETWEEN v_mto_min AND v_mto_max THEN
       V_RETORNO := 'N';
    END IF;

    if instr('*'||v_cod_mon_hab||'*','*'||p_cod_moneda||'*')=0  then--valida Moneda
      v_retorno:= 'N';
    end if;
    --Valida habilitado SPI --
   
   --if pas_spi.fu_val_ente_habilitado(p_cod_swift) ='N' then
   if pas_spi.fu_obt_tra_spi(p_cod_moneda,p_monto,'N', p_cod_swift) = 'N' then
    v_retorno := 'N';
   end if;
     return v_retorno;
  ELSE
    RETURN 'N';
  END IF;

end fug_val_mx_spi;
/

