function renderProjectsPage() {

    const container =
        document.getElementById("projectsContainer");

    if (!container || !siteData?.projects) {
        return;
    }

    container.innerHTML =
        siteData.projects.map(project => {

            const completed =
                project.status === "completed";

            return `
                <article class="content-card">

                    <img
                        class="content-card-image"
                        src="${escapeAttribute(
                            project.image ||
                            "assets/photos/research-01.jpg"
                        )}"
                        alt=""
                    >

                    <div class="content-card-body">

                        <span class="project-status ${
                            completed
                                ? "completed"
                                : ""
                        }">
                            ${
                                completed
                                    ? t("status.completed")
                                    : t("status.current")
                            }
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

        }).join("");
}


function renderTeamPage() {

    const container =
        document.getElementById("teamContainer");

    if (!container || !siteData) {
        return;
    }

    const people = [
        ...(siteData.people?.director || []),
        ...(siteData.people?.professors || []),
        ...(siteData.students || [])
    ];

    container.innerHTML =
        people.map(person => {

            return `
                <article class="person-card">

                    <img
                        class="person-photo"
                        src="${escapeAttribute(
                            person.photo ||
                            "assets/people/default.jpg"
                        )}"
                        alt="${escapeAttribute(
                            person.name
                        )}"
                    >

                    <div class="person-body">

                        <h3>
                            ${escapeHTML(person.name)}
                        </h3>

                        <div class="person-position">

                            ${
                                localized(
                                    person.position
                                    || person.program
                                    || ""
                                )
                            }

                        </div>

                        ${
                            person.specialization
                                ? `
                                    <div class="person-specialization">
                                        ${
                                            escapeHTML(
                                                localized(
                                                    person.specialization
                                                )
                                            )
                                        }
                                    </div>
                                `
                                : ""
                        }

                    </div>

                </article>
            `;

        }).join("");
}


function renderPublicationsPage() {

    const container =
        document.getElementById(
            "publicationsContainer"
        );

    if (!container) return;

    const publications =
        siteData.publications || [];

    container.innerHTML =
        publications
            .sort(
                (a, b) =>
                    Number(b.year) -
                    Number(a.year)
            )
            .map(publication => {

                return `
                    <article class="publication">

                        <div class="publication-year">
                            ${publication.year}
                        </div>

                        <h3>
                            ${escapeHTML(
                                localized(
                                    publication.title
                                )
                            )}
                        </h3>

                        <div class="publication-authors">
                            ${escapeHTML(
                                publication.authors
                                    ?.join(", ") || ""
                            )}
                        </div>

                        <div>
                            ${escapeHTML(
                                publication.venue || ""
                            )}
                        </div>

                        <div class="publication-links">

                            ${
                                publication.doi
                                    ? `
                                        <a
                                            href="${escapeAttribute(
                                                publication.doi
                                            )}"
                                            target="_blank"
                                            rel="noopener"
                                        >
                                            DOI
                                        </a>
                                    `
                                    : ""
                            }

                            ${
                                publication.url
                                    ? `
                                        <a
                                            href="${escapeAttribute(
                                                publication.url
                                            )}"
                                            target="_blank"
                                            rel="noopener"
                                        >
                                            ${
                                                currentLanguage === "es"
                                                    ? "Ver publicación"
                                                    : "View publication"
                                            }
                                        </a>
                                    `
                                    : ""
                            }

                        </div>

                    </article>
                `;

            })
            .join("");
}


function renderGalleryPage() {

    const container =
        document.getElementById("galleryContainer");

    if (!container) return;

    container.innerHTML =
        (siteData.gallery || [])
            .map(photo => {

                return `
                    <figure class="gallery-item">

                        <img
                            src="${escapeAttribute(
                                photo.image
                            )}"
                            alt="${escapeAttribute(
                                localized(photo.title)
                            )}"
                            loading="lazy"
                        >

                        <figcaption class="gallery-caption">
                            ${escapeHTML(
                                localized(photo.title)
                            )}
                        </figcaption>

                    </figure>
                `;

            })
            .join("");
}
