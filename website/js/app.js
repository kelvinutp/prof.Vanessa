const DATA_URL = "data/base.json";

let siteData = null;

let currentLanguage =
    localStorage.getItem("giset-language") || "es";


const translations = {

    es: {
        nav: {
            home: "Inicio",
            research: "Investigación",
            projects: "Proyectos",
            publications: "Publicaciones",
            team: "Equipo",
            collaborators: "Colaboradores",
            events: "Eventos",
            gallery: "Galería",
            contact: "Contacto"
        },

        hero: {
            label: "Investigación · Innovación · Sostenibilidad",
            explore: "Explorar investigación",
            contact: "Contactarnos"
        },

        research: {
            eyebrow: "Áreas de investigación",
            heading: "Investigación para resolver desafíos reales",
            intro: "Nuestro trabajo integra energía, telecomunicaciones y tecnologías emergentes para desarrollar soluciones con impacto."
        },

        projects: {
            eyebrow: "Proyectos",
            heading: "Investigación en acción",
            viewAll: "Ver todos los proyectos"
        },

        about: {
            eyebrow: "Nuestro grupo",
            heading: "Ciencia, formación y colaboración",
            missionLabel: "Misión"
        },

        stats: {
            projects: "Proyectos",
            people: "Investigadores y estudiantes",
            publications: "Publicaciones"
        },

        cta: {
            eyebrow: "Conectemos",
            heading: "¿Quieres colaborar con nuestro grupo?",
            text: "Estamos abiertos a nuevas colaboraciones académicas, científicas y tecnológicas.",
            button: "Contactar"
        },

        footer: {
            navigation: "Navegación",
            contact: "Contacto"
        },

        status: {
            current: "En curso",
            completed: "Completado"
        }
    },


    en: {
        nav: {
            home: "Home",
            research: "Research",
            projects: "Projects",
            publications: "Publications",
            team: "Team",
            collaborators: "Collaborators",
            events: "Events",
            gallery: "Gallery",
            contact: "Contact"
        },

        hero: {
            label: "Research · Innovation · Sustainability",
            explore: "Explore research",
            contact: "Contact us"
        },

        research: {
            eyebrow: "Research areas",
            heading: "Research addressing real-world challenges",
            intro: "Our work integrates energy, telecommunications, and emerging technologies to develop solutions with impact."
        },

        projects: {
            eyebrow: "Projects",
            heading: "Research in action",
            viewAll: "View all projects"
        },

        about: {
            eyebrow: "Our group",
            heading: "Science, education and collaboration",
            missionLabel: "Mission"
        },

        stats: {
            projects: "Projects",
            people: "Researchers and students",
            publications: "Publications"
        },

        cta: {
            eyebrow: "Let's connect",
            heading: "Interested in collaborating with our group?",
            text: "We welcome new academic, scientific and technological collaborations.",
            button: "Contact us"
        },

        footer: {
            navigation: "Navigation",
            contact: "Contact"
        },

        status: {
            current: "Ongoing",
            completed: "Completed"
        }
    }
};


function t(key) {

    const keys = key.split(".");

    let value = translations[currentLanguage];

    for (const keyPart of keys) {
        value = value?.[keyPart];
    }

    return value || key;
}


function localized(value) {

    if (!value) return "";

    if (
        typeof value === "object" &&
        value.es !== undefined
    ) {
        return value[currentLanguage] || value.es;
    }

    return value;
}


async function loadData() {

    try {

        const response =
            await fetch(DATA_URL);

        if (!response.ok) {
            throw new Error(
                `HTTP ${response.status}`
            );
        }

        siteData =
            await response.json();

        initializeSite();

    } catch (error) {

        console.error(
            "Could not load research group data:",
            error
        );

        showDataError();
    }
}


function initializeSite() {

    document.documentElement.lang =
        currentLanguage;

    renderStaticData();
    renderTranslations();
    renderResearchAreas();
    renderFeaturedProjects();
    renderStatistics();

    setupNavigation();
    setupLanguageSwitcher();

    const year =
        document.getElementById("currentYear");

    if (year) {
        year.textContent =
            new Date().getFullYear();
    }
}


function renderStaticData() {

    const group =
        siteData.group;


    document
        .querySelectorAll("[data-group-name]")
        .forEach(element => {

            element.textContent =
                localized(group.name);

        });


    document
        .querySelectorAll("[data-group-description]")
        .forEach(element => {

            element.textContent =
                localized(group.description);

        });


    document
        .querySelectorAll("[data-group-mission]")
        .forEach(element => {

            element.textContent =
                localized(group.mission);

        });


    document
        .querySelectorAll("[data-group-short-name]")
        .forEach(element => {

            element.textContent =
                localized(group.shortName);

        });


    document
        .querySelectorAll("[data-group-faculty]")
        .forEach(element => {

            element.textContent =
                localized(group.faculty);

        });


    document
        .querySelectorAll("[data-group-campus]")
        .forEach(element => {

            element.textContent =
                localized(group.campus);

        });


    document
        .querySelectorAll("[data-contact-email]")
        .forEach(element => {

            element.textContent =
                siteData.contact.email;

        });


    document
        .querySelectorAll("[data-contact-email-link]")
        .forEach(element => {

            element.href =
                `mailto:${siteData.contact.email}`;

        });


    document
        .querySelectorAll("[data-contact-address]")
        .forEach(element => {

            element.textContent =
                localized(siteData.contact.address);

        });


    document
        .querySelectorAll("[data-university-link]")
        .forEach(element => {

            element.href =
                siteData.contact.universityWebsite;

        });
}


function renderTranslations() {

    document
        .querySelectorAll("[data-i18n]")
        .forEach(element => {

            const key =
                element.dataset.i18n;

            element.textContent =
                t(key);

        });
}


function renderResearchAreas() {

    const container =
        document.getElementById("researchAreas");

    if (!container || !siteData.researchAreas) {
        return;
    }

    container.innerHTML =
        siteData.researchAreas
            .map(area => {

                return `
                    <article class="research-card">

                        <div class="research-icon">
                            ${area.icon || "◈"}
                        </div>

                        <h3>
                            ${escapeHTML(
                                localized(area.name)
                            )}
                        </h3>

                        <p>
                            ${escapeHTML(
                                localized(area.description)
                            )}
                        </p>

                    </article>
                `;

            })
            .join("");
}


function renderFeaturedProjects() {

    const container =
        document.getElementById("featuredProjects");

    if (!container || !siteData.projects) {
        return;
    }

    const projects =
        siteData.projects.slice(0, 4);

    container.innerHTML =
        projects
            .map(project => {

                const statusClass =
                    project.status === "completed"
                        ? "completed"
                        : "";

                const statusText =
                    project.status === "completed"
                        ? t("status.completed")
                        : t("status.current");

                const image =
                    project.image ||
                    "assets/photos/research-01.jpg";

                return `
                    <article class="project-card">

                        <div
                            class="project-image"
                            style="
                                background-image:
                                url('${escapeAttribute(image)}')
                            "
                        ></div>

                        <div class="project-body">

                            <span
                                class="project-status ${statusClass}"
                            >
                                ${statusText}
                            </span>

                            <h3>
                                ${escapeHTML(
                                    localized(project.title)
                                )}
                            </h3>

                            <p>
                                ${escapeHTML(
                                    localized(project.summary)
                                )}
                            </p>

                        </div>

                    </article>
                `;

            })
            .join("");
}


function renderStatistics() {

    const projectCount =
        document.getElementById("projectCount");

    const peopleCount =
        document.getElementById("peopleCount");

    const publicationCount =
        document.getElementById("publicationCount");


    if (projectCount) {

        projectCount.textContent =
            siteData.projects?.length || 0;

    }


    if (peopleCount) {

        const director =
            siteData.people?.director?.length || 0;

        const professors =
            siteData.people?.professors?.length || 0;

        const students =
            siteData.students?.length || 0;

        peopleCount.textContent =
            director + professors + students;

    }


    if (publicationCount) {

        publicationCount.textContent =
            siteData.publications?.length || 0;

    }
}


function setupLanguageSwitcher() {

    const button =
        document.getElementById(
            "languageSwitcher"
        );

    if (!button) return;


    button.textContent =
        currentLanguage === "es"
            ? "EN"
            : "ES";


    button.onclick = () => {

        currentLanguage =
            currentLanguage === "es"
                ? "en"
                : "es";


        localStorage.setItem(
            "giset-language",
            currentLanguage
        );


        initializeSite();

        button.textContent =
            currentLanguage === "es"
                ? "EN"
                : "ES";

    };
}


function setupNavigation() {

    const button =
        document.getElementById(
            "mobileMenuButton"
        );

    const navigation =
        document.getElementById(
            "mainNav"
        );


    if (!button || !navigation) {
        return;
    }


    button.onclick = () => {

        const isOpen =
            navigation.classList.toggle(
                "open"
            );

        button.setAttribute(
            "aria-expanded",
            isOpen
        );

    };


    navigation
        .querySelectorAll("a")
        .forEach(link => {

            link.addEventListener(
                "click",
                () => {

                    navigation
                        .classList
                        .remove("open");

                    button.setAttribute(
                        "aria-expanded",
                        "false"
                    );

                }
            );

        });
}


function escapeHTML(value) {

    if (value === undefined || value === null) {
        return "";
    }

    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


function escapeAttribute(value) {

    return escapeHTML(value)
        .replaceAll("`", "");
}


function showDataError() {

    const main =
        document.querySelector("main");

    if (!main) return;

    const message =
        currentLanguage === "es"
            ? "No se pudo cargar la información del grupo de investigación."
            : "The research group information could not be loaded.";

    main.insertAdjacentHTML(
        "afterbegin",
        `
            <div
                style="
                    padding: 20px;
                    background: #fee2e2;
                    color: #991b1b;
                    text-align: center;
                "
            >
                ${message}
            </div>
        `
    );
}


async function startApplication() {

    await loadData();

    if (!siteData) {
        return;
    }

    const page =
        document.body.dataset.page;

    switch (page) {

        case "projects":
            renderProjectsPage();
            break;

        case "team":
            renderTeamPage();
            break;

        case "publications":
            renderPublicationsPage();
            break;

        case "gallery":
            renderGalleryPage();
            break;

    }
}


startApplication();

