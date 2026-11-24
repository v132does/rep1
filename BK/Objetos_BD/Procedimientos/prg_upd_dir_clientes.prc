CREATE OR REPLACE Procedure IT.PRG_UPD_DIR_CLIENTES(PNRO_CUENTA Varchar2,
																								 PDIRECCION1 Varchar2,
																								 PDIRECCION2 Varchar2,
																								 PDIRECCION3 Varchar2,
																								 PCIUDAD     Number,
																								 PSI_PROCESO Out Varchar2,
																								 PMENSAJE    Out Varchar2) Is
		 --varibales normales
		 VPERSONA    BA_PERSONAS.COD_PERSONA%Type;
		 VREFERENCIA GE_DIR_ENVIOS.REFERENCIA%Type; --para utilizar luego en el match "cod_direccion = vreferencia"
		 VDIRECCION  Varchar2(80); --variable para ir guardando las direcciones
		 VCODIGO     Number(2); --para almacenar el codigo siguiente en direcciones 
		 VNRO_CUENTA GE_DIR_ENVIOS.NRO_CUENTA%Type;
		 --manejo de error
		 VERROR EXCEPTION ;
Begin
		 ---------------------------------------------------------
		 -- ACTUALIZA O INSERTA LAS DIRECCIONES DE LOS CLIENTES --
		 ---------------------------------------------------------
     PSI_PROCESO := 'S';
     
     --verifica que el nro de cuenta no este nula
		 If PNRO_CUENTA Is Null Then
					PMENSAJE := 'Lugar_1 = EL CAMPO CUENTA ESTA VACIA';
					Raise VERROR;
		 ELSE
       --depura la cadena para que no haya espacios
					VNRO_CUENTA := PAW_BEL.DEPURARALFANUMERICO(PNRO_CUENTA, 15);
		 End If;
		 
		 --obtiene el codigo de persona y la referencia
		 Begin
					Select E.COD_PERSONA,
								 E.REFERENCIA
						Into VPERSONA,
								 VREFERENCIA
						From GE_DIR_ENVIOS E
					 Where E.NRO_CUENTA = VNRO_CUENTA
						 And E.TIP_ENVIO = 'D';
		 Exception
					When NO_DATA_FOUND Then
							 Begin
										Select E.COD_PERSONA
											Into VPERSONA
											From GE_DIR_ENVIOS E
										 Where E.NRO_CUENTA = VNRO_CUENTA
										 Group By E.COD_PERSONA;
							 Exception
										When NO_DATA_FOUND Then
												 VPERSONA := FUG_OBT_CLI_PRINCIPAL(VNRO_CUENTA);
												 If VPERSONA Is Null Then
															PMENSAJE := 'Lugar_2 = LA CUENTA ' ||
																					VNRO_CUENTA || ' NO EXISTE';
															Raise VERROR;
												 End If;
										When Others Then
												 PMENSAJE := 'Lugar_3 = ' || Sqlerrm;
												 Raise VERROR;
							 End;
					When Others Then
							 PMENSAJE := 'Lugar_4 = ' || Sqlerrm;
							 Raise VERROR;
		 End;
		 --asigna la direccion y setea una longitud fija de 80 caracteres
		 VDIRECCION := RPAD(SUBSTR(PDIRECCION1 || ' ' || PDIRECCION2 || ' ' ||
															 PDIRECCION3, 1, 80), 80, ' ');
		 --se actualiza la direccion si existe con el tipo 'R' --> CRM
		 Update BA_DIRECCIONES B
				Set B.DIRECCION  = VDIRECCION,
						B.COD_CIUDAD = PCIUDAD
			Where B.COD_PERSONA = VPERSONA
				And B.TIPO = 'R'
				And B.COD_DIRECCION = VREFERENCIA;

		 If Sql%Notfound Then
					--obtenemos el siguiente codigo a insertar
					Begin
							 Select MAX(nvl(d.cod_direccion,0)) + 1
								 Into VCODIGO
								 From BA_DIRECCIONES D
								Where D.COD_PERSONA = VPERSONA;
					Exception
							 When NO_DATA_FOUND Then
										VCODIGO := 1;
							 When Others Then
										PMENSAJE := 'Lugar_5 = ' || Sqlerrm;
										Raise VERROR;
					End;
					---si no encuentra entonces se inserta un registro nuevo
					Begin
							 Insert Into BA_DIRECCIONES 
										(COD_PERSONA,
										 COD_DIRECCION,
										 TIPO,
										 DIRECCION,
										 COD_PAIS,
                     COD_CIUDAD,
										 OBSERVACION)
							 Values
										(VPERSONA,
										 VCODIGO,
										 'R',
										 VDIRECCION,
										 1,
                     PCIUDAD,
										 Null);
					Exception
							 When Others Then
										PMENSAJE := 'Lugar_6 = ' || Sqlerrm;
										Raise VERROR;
					End;
					--actualizamos la referencia en ge_dir_envios si existe
					Update GE_DIR_ENVIOS D
						 Set D.REFERENCIA = VCODIGO
					 Where D.NRO_CUENTA = VNRO_CUENTA
						 And D.COD_PERSONA = VPERSONA;
					If Sql%Notfound Then
							 --si no existe insertamos 
							 Begin
										Insert Into GE_DIR_ENVIOS
												 (COD_PERSONA,
													TIP_ENVIO,
													REFERENCIA,
													NRO_CUENTA,
													OBSERVACION)
										VALUES
												 (VPERSONA,
													'D',
													VCODIGO,
													VNRO_CUENTA,
													'Dirección Bancard');
							 Exception
										When Others Then
												 PMENSAJE := 'Lugar_7 = ' || Sqlerrm;
												  Raise VERROR;
							 End;
					End If;
		 End If;
		 If PSI_PROCESO = 'S' Then
					PMENSAJE := 'OK';
		 Else
					Rollback;
		 End If;
Exception
		 When VERROR Then
					PSI_PROCESO := 'N';
		 When Others Then
					RAISE_APPLICATION_ERROR(-20001, 'Error : ' || Sqlerrm);
End;
/

